package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

const (
	// RSS feed URL for Harness CI release notes
	HarnessRSSFeedURL = "https://developer.harness.io/release-notes/continuous-integration/rss.xml"

	// User agent for the HTTP client
	UserAgent = "Harness-CI-Image-Monitor/1.0"

	// Default check interval in minutes
	DefaultCheckInterval = 60

	// Path to store the last processed release
	DefaultStateFile = "last_processed_release.json"
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
func fetchRSSFeed(url string) (*RSS, error) {
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
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// Read response body
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Parse XML
	rss := &RSS{}
	err = xml.Unmarshal(body, rss)
	if err != nil {
		return nil, err
	}

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

// Process RSS feed items
func processRSSFeed(config *Config) error {
	// Load state
	state, err := loadState(config.StateFilePath)
	if err != nil {
		return fmt.Errorf("failed to load state: %v", err)
	}

	// Fetch RSS feed
	rss, err := fetchRSSFeed(HarnessRSSFeedURL)
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

		// Parse publish date
		pubDate, err := time.Parse(time.RFC1123Z, item.PubDate)
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
