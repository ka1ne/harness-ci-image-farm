package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

const (
	// RSS feed URL for Harness CI release notes
	HarnessRSSFeedURL = "https://developer.harness.io/release-notes/continuous-integration/rss.xml"
	// Local test feed when in test mode
	TestRSSFeedURL = "http://localhost:8080/rss.xml"

	// User agent for the HTTP client
	UserAgent = "Harness-CI-Image-Monitor/1.0"

	// Default check interval in minutes
	DefaultCheckInterval = 1 // Reduced for testing

	// Path to store the last processed release
	DefaultStateFile = "/app/data/last_processed_release.json"
)

// RSS Feed structures
type RSS struct {
	XMLName xml.Name `xml:"rss"`
	Channel Channel  `xml:"channel"`
}

type Channel struct {
	Title       string `xml:"title"`
	Description string `xml:"description"`
	Link        string `xml:"link"`
	Items       []Item `xml:"item"`
}

type Item struct {
	Title       string `xml:"title"`
	Link        string `xml:"link"`
	PubDate     string `xml:"pubDate"`
	Description string `xml:"description"`
	Content     string `xml:"encoded"`
}

// State structure to track the last processed release
type State struct {
	LastProcessedDate string            `json:"last_processed_date"`
	LastImageVersions map[string]string `json:"last_image_versions"`
}

// WebhookPayload structure to send to Harness
type WebhookPayload struct {
	Version       string   `json:"version"`
	UpdatedImages string   `json:"updated_images"`
	ImageList     []string `json:"image_list"`
	ReleaseDate   string   `json:"release_date"`
}

// Configuration structure
type Config struct {
	HarnessWebhookURL string
	HarnessAPIKey     string
	StateFilePath     string
	CheckInterval     int
	DebugMode         bool
}

// Parse command line arguments and environment variables
func parseConfig() *Config {
	config := &Config{}

	// Command line arguments
	flag.StringVar(&config.HarnessWebhookURL, "webhook-url", os.Getenv("HARNESS_WEBHOOK_URL"), "Harness webhook URL")
	flag.StringVar(&config.HarnessAPIKey, "api-key", os.Getenv("HARNESS_API_KEY"), "Harness API key")
	flag.StringVar(&config.StateFilePath, "state-file", os.Getenv("STATE_FILE_PATH"), "Path to state file")
	intervalStr := flag.String("interval", os.Getenv("CHECK_INTERVAL"), "Check interval in minutes")
	flag.BoolVar(&config.DebugMode, "debug", os.Getenv("DEBUG_MODE") == "true", "Enable debug mode")
	testMode := os.Getenv("TEST_MODE") == "true"

	flag.Parse()

	// Set default values if not provided
	if config.StateFilePath == "" {
		config.StateFilePath = DefaultStateFile
	}

	if *intervalStr == "" {
		config.CheckInterval = DefaultCheckInterval
	} else {
		fmt.Sscanf(*intervalStr, "%d", &config.CheckInterval)
		if config.CheckInterval < 1 {
			config.CheckInterval = DefaultCheckInterval
		}
	}

	// In test mode, we use a different feed URL
	if testMode {
		log.Println("Running in TEST MODE - using local mock server")
		startMockServer()
		// Wait for the server to start
		time.Sleep(500 * time.Millisecond)
	}

	// Validate required configuration
	if config.HarnessWebhookURL == "" {
		log.Fatal("Harness webhook URL is required. Set it via -webhook-url flag or HARNESS_WEBHOOK_URL environment variable.")
	}

	if config.HarnessAPIKey == "" {
		log.Fatal("Harness API key is required. Set it via -api-key flag or HARNESS_API_KEY environment variable.")
	}

	return config
}

// Load the last processed state
func loadState(filePath string) (*State, error) {
	state := &State{
		LastImageVersions: make(map[string]string),
	}

	// Check if the file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return state, nil
	}

	// Read the file
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	// Unmarshal the JSON
	err = json.Unmarshal(data, state)
	if err != nil {
		return nil, err
	}

	return state, nil
}

// Save the current state
func saveState(state *State, filePath string) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}

	return ioutil.WriteFile(filePath, data, 0644)
}

// Fetch the RSS feed
func fetchRSSFeed(url string, debug bool) (*RSS, error) {
	log.Printf("Fetching RSS feed from: %s", url)

	// Create HTTP client
	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	// Create request
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	// Set headers
	req.Header.Set("User-Agent", UserAgent)

	// Send request
	log.Printf("Sending HTTP request...")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	log.Printf("Received HTTP response with status: %s", resp.Status)

	// Read response body
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if debug {
		log.Printf("Response body: %s", string(body))
	}

	// Parse XML
	rss := &RSS{}
	err = xml.Unmarshal(body, rss)
	if err != nil {
		return nil, err
	}

	log.Printf("Successfully parsed RSS feed with %d items", len(rss.Channel.Items))
	return rss, nil
}

// Extract image updates from RSS item
func extractImageUpdates(content string) map[string]string {
	updates := make(map[string]string)

	// Regular expression to extract image updates
	re := regexp.MustCompile(`\|(.*?)\|(.*?)\|(.*?)\|`)
	matches := re.FindAllStringSubmatch(content, -1)

	for _, match := range matches {
		if len(match) >= 4 {
			imageName := strings.TrimSpace(match[1])
			newVersion := strings.TrimSpace(match[3])

			// Only include harness/* images
			if strings.HasPrefix(imageName, "harness/") {
				updates[imageName] = newVersion
			}
		}
	}

	return updates
}

// Send webhook to Harness
func sendWebhook(webhookURL, apiKey string, payload *WebhookPayload, debug bool) error {
	// Marshal the payload
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	if debug {
		log.Printf("Webhook payload: %s", string(data))
	}

	// Create HTTP client
	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	// Create request
	req, err := http.NewRequest("POST", webhookURL, bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Harness-RSS-Event", "ci-release")
	req.Header.Set("X-API-Key", apiKey)

	// Send request
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Check response status
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := ioutil.ReadAll(resp.Body)
		return fmt.Errorf("webhook request failed with status %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// Create a mock RSS feed for testing
func startMockServer() {
	// Create the initial RSS feed
	rss := &RSS{
		Channel: Channel{
			Title:       "Harness CI Release Notes",
			Description: "Latest release notes for Harness CI",
			Link:        "https://developer.harness.io/release-notes/continuous-integration",
			Items: []Item{
				{
					Title:       "Harness CI 1.15.0",
					Link:        "https://developer.harness.io/release-notes/continuous-integration/1.15.0",
					PubDate:     time.Now().Add(-24 * time.Hour).Format(time.RFC1123),
					Description: "Harness CI 1.15.0 Release Notes",
					Content:     "<h2>Image Updates</h2><table><thead><tr><th>Image</th><th>Old Version</th><th>New Version</th></tr></thead><tbody><tr><td>harness/ci-manager</td><td>1.14.0</td><td>1.15.0</td></tr><tr><td>harness/drone-git</td><td>1.1.0</td><td>1.2.0</td></tr><tr><td>harness/drone-runner</td><td>1.0.1</td><td>1.1.0</td></tr></tbody></table>",
				},
			},
		},
	}

	// Start the HTTP server
	http.HandleFunc("/rss.xml", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/xml")

		// Add a new release 10% of the time
		if rand.Float32() < 0.1 {
			log.Println("Adding a new release to the mock feed")
			addNewRelease(rss)
		}

		// Marshal the RSS feed to XML
		output, err := xml.MarshalIndent(rss, "", "  ")
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Write the XML declaration and then the RSS feed
		w.Write([]byte(xml.Header))
		w.Write(output)
	})

	// Start the server in a goroutine
	go func() {
		log.Println("Starting mock RSS feed server on http://localhost:8080/rss.xml")
		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Printf("Mock server error: %v", err)
		}
	}()
}

// Add a new release to the mock RSS feed
func addNewRelease(rss *RSS) {
	// Generate a new version
	major := rand.Intn(2) + 1
	minor := rand.Intn(20)
	patch := rand.Intn(10)
	version := fmt.Sprintf("%d.%d.%d", major, minor, patch)

	// Create a new item
	newItem := Item{
		Title:       fmt.Sprintf("Harness CI %s", version),
		Link:        fmt.Sprintf("https://developer.harness.io/release-notes/continuous-integration/%s", version),
		PubDate:     time.Now().Format(time.RFC1123),
		Description: fmt.Sprintf("Harness CI %s Release Notes", version),
		Content:     fmt.Sprintf("<h2>Image Updates</h2><table><thead><tr><th>Image</th><th>Old Version</th><th>New Version</th></tr></thead><tbody><tr><td>harness/ci-manager</td><td>1.15.0</td><td>%s</td></tr><tr><td>harness/drone-git</td><td>1.2.0</td><td>1.3.0</td></tr><tr><td>harness/drone-runner</td><td>1.1.0</td><td>1.2.0</td></tr></tbody></table>", version),
	}

	// Insert the new item at the beginning
	rss.Channel.Items = append([]Item{newItem}, rss.Channel.Items...)

	log.Printf("Added new release: Harness CI %s", version)
}

// Process RSS feed items
func processRSSFeed(config *Config) error {
	// Load state
	state, err := loadState(config.StateFilePath)
	if err != nil {
		return fmt.Errorf("failed to load state: %v", err)
	}

	// Determine which feed URL to use based on TEST_MODE
	feedURL := HarnessRSSFeedURL
	if os.Getenv("TEST_MODE") == "true" {
		feedURL = TestRSSFeedURL
	}

	// Fetch RSS feed
	rss, err := fetchRSSFeed(feedURL, config.DebugMode)
	if err != nil {
		return fmt.Errorf("failed to fetch RSS feed: %v", err)
	}

	if len(rss.Channel.Items) == 0 {
		log.Println("No items found in RSS feed")
		return nil
	}

	// Process items in reverse order (oldest first)
	for i := len(rss.Channel.Items) - 1; i >= 0; i-- {
		item := rss.Channel.Items[i]

		// Parse the publish date
		pubDate, err := time.Parse(time.RFC1123, item.PubDate)
		if err != nil {
			log.Printf("Failed to parse publish date '%s': %v", item.PubDate, err)
			continue
		}

		// Skip if already processed
		if state.LastProcessedDate != "" {
			lastDate, err := time.Parse(time.RFC3339, state.LastProcessedDate)
			if err == nil && !pubDate.After(lastDate) {
				if config.DebugMode {
					log.Printf("Skipping already processed item: %s", item.Title)
				}
				continue
			}
		}

		// Check if it contains image updates
		if strings.Contains(item.Content, "Image") && strings.Contains(item.Content, "harness/") {
			log.Printf("Processing release: %s (%s)", item.Title, pubDate.Format(time.RFC3339))

			// Extract image updates
			updates := extractImageUpdates(item.Content)

			if len(updates) > 0 {
				// Build list of updated images
				var updatedImages []string
				for image, version := range updates {
					// Check if the image version has changed
					if prevVersion, ok := state.LastImageVersions[image]; !ok || prevVersion != version {
						updatedImages = append(updatedImages, fmt.Sprintf("%s:%s", image, version))
						state.LastImageVersions[image] = version
					}
				}

				if len(updatedImages) > 0 {
					// Create webhook payload
					payload := &WebhookPayload{
						Version:       item.Title,
						UpdatedImages: strings.Join(updatedImages, ","),
						ImageList:     updatedImages,
						ReleaseDate:   pubDate.Format(time.RFC3339),
					}

					// Send webhook
					log.Printf("Sending webhook with %d updated images", len(updatedImages))
					err := sendWebhook(config.HarnessWebhookURL, config.HarnessAPIKey, payload, config.DebugMode)
					if err != nil {
						log.Printf("Failed to send webhook: %v", err)
					} else {
						log.Println("Webhook sent successfully")
					}
				} else {
					log.Println("No new image versions detected")
				}
			} else {
				log.Println("No image updates found in release")
			}
		}

		// Update last processed date
		state.LastProcessedDate = pubDate.Format(time.RFC3339)
	}

	// Save state
	err = saveState(state, config.StateFilePath)
	if err != nil {
		return fmt.Errorf("failed to save state: %v", err)
	}

	return nil
}

func main() {
	// Initialize random seed
	rand.Seed(time.Now().UnixNano())

	// Parse configuration
	config := parseConfig()

	log.Printf("Starting Harness CI RSS monitor (interval: %d minutes)", config.CheckInterval)

	// Run once immediately
	err := processRSSFeed(config)
	if err != nil {
		log.Printf("Error processing RSS feed: %v", err)
	}

	// Set up ticker for regular checks
	ticker := time.NewTicker(time.Duration(config.CheckInterval) * time.Minute)
	defer ticker.Stop()

	// Main loop
	for {
		select {
		case <-ticker.C:
			log.Println("Checking for updates...")
			err := processRSSFeed(config)
			if err != nil {
				log.Printf("Error processing RSS feed: %v", err)
			}
		}
	}
}
