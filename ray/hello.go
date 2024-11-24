package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"time"
	"net/http"
)

func main() {
	http.HandleFunc("/", HelloServer)
	http.ListenAndServe("localhost:60003", nil)
	//http.ListenAndServeTLS("localhost:60003", "/etc/xray/xray.crt", "/etc/xray/xray.key", nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
	//fmt.Fprintf(w, "Hello, %s!", r.URL.Path[1:])
	complexJSON, err := generateComplexJSON()
	if err != nil {
		fmt.Println("Error generating JSON:", err)
		return
	}
	fmt.Fprintf(w, complexJSON)
}

// 定义更复杂的 JSON 结构体
type APIResponse struct {
	Code    string         `json:"code"`
	Message string         `json:"msg"`
	Payload PayloadData    `json:"data"`
	Meta    AdditionalInfo `json:"meta"`
}

type PayloadData struct {
	ID          int           `json:"identifier"`
	Title       string        `json:"name"`
	Timestamp   string        `json:"datetime"`
	Description string        `json:"info"`
	SubData     NestedData    `json:"details"`
	Items       []Item        `json:"items"`
	Attributes  Attribute     `json:"attributes"`
	Links       []Link        `json:"links"`
	Tags        []string      `json:"tags"`
	History     []Event       `json:"history"`
}

type NestedData struct {
	Section    string `json:"section"`
	Level      int    `json:"rank"`
	SubSection string `json:"subsection"`
	Meta       Meta   `json:"meta"`
}

type Meta struct {
	CreatedAt  string `json:"created_at"`
	UpdatedAt  string `json:"updated_at"`
	Version    string `json:"version"`
	Generated  bool   `json:"generated"`
}

type Item struct {
	UniqueID  int     `json:"item_id"`
	Label     string  `json:"item_label"`
	UnitPrice float64 `json:"price"`
	Category  string  `json:"category"`
	Quantity  int     `json:"quantity"`
	Weight    float64 `json:"weight"`
	Size      string  `json:"size"`
}

type Link struct {
	Rel  string `json:"rel"`
	Href string `json:"href"`
}

type Event struct {
	EventID   int       `json:"event_id"`
	Timestamp string    `json:"timestamp"`
	Action    string    `json:"action"`
	Details   string    `json:"details"`
}

type Attribute struct {
	Color    string  `json:"color"`
	Weight   float64 `json:"weight"`
	Size     string  `json:"size"`
	Material string  `json:"material"`
}

type AdditionalInfo struct {
	TotalCount    int `json:"total"`
	PageNum       int `json:"page"`
	ItemsPerPage  int `json:"per_page"`
	TotalPages    int `json:"total_pages"`
	CurrentOffset int `json:"current_offset"`
}

func generateRandomString(length int) string {
	chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var result string
	for i := 0; i < length; i++ {
		result += string(chars[rand.Intn(len(chars))])
	}
	return result
}

func generateRandomCategory() string {
	categories := []string{"Electronics", "Furniture", "Clothing", "Sports", "Books", "Food", "Toys", "Automotive", "Health", "Beauty"}
	return categories[rand.Intn(len(categories))]
}

func generateRandomColor() string {
	colors := []string{"Red", "Green", "Blue", "Yellow", "Black", "White", "Pink", "Orange", "Purple", "Gray"}
	return colors[rand.Intn(len(colors))]
}

func generateRandomEventAction() string {
	actions := []string{"Created", "Updated", "Deleted", "Processed", "Reviewed", "Verified", "Shipped", "Returned"}
	return actions[rand.Intn(len(actions))]
}

func generateComplexJSON() (string, error) {
	// 设置随机数种子
	rand.Seed(time.Now().UnixNano())

	// 构建复杂的 API 返回数据
	response := APIResponse{
		Code:    "200",
		Message: "Request successful",
		Payload: PayloadData{
			ID:          rand.Intn(100000),
			Title:       generateRandomString(25),
			Timestamp:   time.Now().Format(time.RFC3339),
			Description: generateRandomString(100),
			SubData: NestedData{
				Section:   generateRandomString(8),
				Level:     rand.Intn(10),
				SubSection: generateRandomString(12),
				Meta: Meta{
					CreatedAt:  time.Now().Format(time.RFC3339),
					UpdatedAt:  time.Now().Format(time.RFC3339),
					Version:    "v1.0.0",
					Generated:  true,
				},
			},
			Items: []Item{
				{
					UniqueID:  rand.Intn(10000),
					Label:     "Gadget " + generateRandomString(6),
					UnitPrice: rand.Float64() * 200,
					Category:  generateRandomCategory(),
					Quantity:  rand.Intn(100),
					Weight:    rand.Float64() * 50,
					Size:      generateRandomString(3),
				},
				{
					UniqueID:  rand.Intn(10000),
					Label:     "Item " + generateRandomString(6),
					UnitPrice: rand.Float64() * 150,
					Category:  generateRandomCategory(),
					Quantity:  rand.Intn(100),
					Weight:    rand.Float64() * 30,
					Size:      generateRandomString(3),
				},
				{
					UniqueID:  rand.Intn(10000),
					Label:     "Product " + generateRandomString(6),
					UnitPrice: rand.Float64() * 500,
					Category:  generateRandomCategory(),
					Quantity:  rand.Intn(100),
					Weight:    rand.Float64() * 60,
					Size:      generateRandomString(3),
				},
			},
			Attributes: Attribute{
				Color:    generateRandomColor(),
				Weight:   rand.Float64() * 100,
				Size:     generateRandomString(2),
				Material: "Plastic",
			},
			Links: []Link{
				{Rel: "self", Href: "https://example.com/api/item/1"},
				{Rel: "next", Href: "https://example.com/api/item/2"},
			},
			Tags: []string{"New", "Sale", "Featured", "Discounted", "Popular", "Limited"},
			History: []Event{
				{
					EventID:   rand.Intn(10000),
					Timestamp: time.Now().Format(time.RFC3339),
					Action:    generateRandomEventAction(),
					Details:   generateRandomString(50),
				},
				{
					EventID:   rand.Intn(10000),
					Timestamp: time.Now().Format(time.RFC3339),
					Action:    generateRandomEventAction(),
					Details:   generateRandomString(50),
				},
				{
					EventID:   rand.Intn(10000),
					Timestamp: time.Now().Format(time.RFC3339),
					Action:    generateRandomEventAction(),
					Details:   generateRandomString(50),
				},
			},
		},
		Meta: AdditionalInfo{
			TotalCount:    1000,
			PageNum:       rand.Intn(50) + 1,
			ItemsPerPage:  20,
			TotalPages:    50,
			CurrentOffset: rand.Intn(100),
		},
	}

	// 将结构体转换为 JSON 字符串
	jsonData, err := json.MarshalIndent(response, "", "    ")
	if err != nil {
		return "", err
	}
	return string(jsonData), nil
}
