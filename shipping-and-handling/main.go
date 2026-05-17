package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	requestTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)
	requestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)
)

func init() {
	prometheus.MustRegister(requestTotal)
	prometheus.MustRegister(requestDuration)
}

func metricsMiddleware(path string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &responseWriter{ResponseWriter: w, status: 200}
		next(rw, r)
		duration := time.Since(start).Seconds()
		requestTotal.WithLabelValues(r.Method, path, strconv.Itoa(rw.status)).Inc()
		requestDuration.WithLabelValues(r.Method, path).Observe(duration)
	}
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(status int) {
	rw.status = status
	rw.ResponseWriter.WriteHeader(status)
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	}
}

type Product struct {
	ID          int     `json:"id" bson:"id"`
	Name        string  `json:"name" bson:"name"`
	Description string  `json:"description" bson:"description"`
	Price       float64 `json:"price" bson:"price"`
	Category    string  `json:"category" bson:"category"`
}

var productsCollection *mongo.Collection

func initMongo() {
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}
	clientOptions := options.Client().ApplyURI(mongoURI)
	client, err := mongo.Connect(context.Background(), clientOptions)
	if err != nil {
		log.Fatal(err)
	}
	productsCollection = client.Database("shipping_handling").Collection("products")
	count, err := productsCollection.CountDocuments(context.Background(), bson.M{})
	if err != nil {
		log.Fatal(err)
	}
	if count == 0 {
		initialProducts := []interface{}{
			Product{ID: 1, Name: "Wireless Bluetooth Headphones", Description: "High-quality sound", Price: 59.99, Category: "Electronics"},
			Product{ID: 2, Name: "Vintage Leather Backpack", Description: "Stylish backpack", Price: 89.99, Category: "Accessories"},
			Product{ID: 3, Name: "Stainless Steel Water Bottle", Description: "Eco-friendly bottle", Price: 19.99, Category: "Home & Kitchen"},
			Product{ID: 4, Name: "Organic Green Tea", Description: "Refreshing tea", Price: 15.99, Category: "Groceries"},
			Product{ID: 5, Name: "Smartwatch Fitness Tracker", Description: "Track fitness", Price: 199.99, Category: "Electronics"},
			Product{ID: 6, Name: "Professional Studio Microphone", Description: "Record audio", Price: 129.99, Category: "Electronics"},
			Product{ID: 7, Name: "Ergonomic Office Chair", Description: "Comfortable chair", Price: 249.99, Category: "Office Supplies"},
			Product{ID: 8, Name: "LED Desk Lamp", Description: "Energy-efficient lamp", Price: 39.99, Category: "Home & Kitchen"},
			Product{ID: 9, Name: "Gourmet Chocolate Box", Description: "Gourmet chocolates", Price: 29.99, Category: "Groceries"},
			Product{ID: 10, Name: "Yoga Mat with Carrying Strap", Description: "Non-slip yoga mat", Price: 49.99, Category: "Fitness"},
			Product{ID: 11, Name: "Insulated Camping Tent", Description: "Durable tent", Price: 349.99, Category: "Outdoor"},
			Product{ID: 12, Name: "Bluetooth Speaker", Description: "Portable speaker", Price: 99.99, Category: "Electronics"},
		}
		_, err := productsCollection.InsertMany(context.Background(), initialProducts)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println("Inserted initial product data")
	}
}

func calculateShippingFee(category string) float64 {
	baseFee := 5.0
	var categoryMultiplier float64
	timeOfDaySurcharge := 0.0
	peakHoursStart := 14
	peakHoursEnd := 19
	switch category {
	case "Electronics":
		categoryMultiplier = 2.0
	case "Office Supplies":
		categoryMultiplier = 1.8
	case "Home & Kitchen":
		categoryMultiplier = 1.5
	case "Groceries":
		categoryMultiplier = 1.2
	case "Fitness", "Outdoor":
		categoryMultiplier = 1.4
	default:
		categoryMultiplier = 1.0
	}
	currentHour := time.Now().Hour()
	if currentHour >= peakHoursStart && currentHour <= peakHoursEnd {
		timeOfDaySurcharge = 3.0
	}
	return baseFee*categoryMultiplier + timeOfDaySurcharge
}

func handleShippingFee(w http.ResponseWriter, r *http.Request) {
	productIDStr := r.URL.Query().Get("product_id")
	if productIDStr == "" {
		http.Error(w, "Product ID is required", http.StatusBadRequest)
		return
	}
	productID, err := strconv.Atoi(productIDStr)
	if err != nil {
		http.Error(w, "Invalid product ID", http.StatusBadRequest)
		return
	}
	var product Product
	err = productsCollection.FindOne(context.Background(), bson.M{"id": productID}).Decode(&product)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			http.Error(w, "Product not found", http.StatusNotFound)
		} else {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
		return
	}
	shippingFee := calculateShippingFee(product.Category)
	response := struct {
		ID          int     `json:"id"`
		Name        string  `json:"name"`
		Description string  `json:"description"`
		Price       float64 `json:"price"`
		Category    string  `json:"category"`
		ShippingFee float64 `json:"shipping_fee"`
	}{product.ID, product.Name, product.Description, product.Price, product.Category, shippingFee}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func handleShippingExplanation(w http.ResponseWriter, r *http.Request) {
	explanation := map[string]string{"explanation": "Shipping fees are calculated based on product category and time of day surcharges during peak hours (2 PM - 7 PM)."}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(explanation)
}

func handleAllShippingFees(w http.ResponseWriter, r *http.Request) {
	cursor, err := productsCollection.Find(context.Background(), bson.M{})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())
	var feeDetails []struct {
		ProductID   int     `json:"product_id"`
		ShippingFee float64 `json:"shipping_fee"`
		Price       float64 `json:"price"`
		Name        string  `json:"name"`
		Description string  `json:"description"`
		Category    string  `json:"category"`
	}
	for cursor.Next(context.Background()) {
		var product Product
		if err := cursor.Decode(&product); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		fee := calculateShippingFee(product.Category)
		feeDetails = append(feeDetails, struct {
			ProductID   int     `json:"product_id"`
			ShippingFee float64 `json:"shipping_fee"`
			Price       float64 `json:"price"`
			Name        string  `json:"name"`
			Description string  `json:"description"`
			Category    string  `json:"category"`
		}{product.ID, fee, product.Price, product.Name, product.Description, product.Category})
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(feeDetails)
}

func main() {
	initMongo()

	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/shipping-fee", corsMiddleware(metricsMiddleware("/shipping-fee", handleShippingFee)))
	http.HandleFunc("/shipping-explanation", corsMiddleware(metricsMiddleware("/shipping-explanation", handleShippingExplanation)))
	http.HandleFunc("/all-shipping-fees", corsMiddleware(metricsMiddleware("/all-shipping-fees", handleAllShippingFees)))
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy","service":"shipping-and-handling"}`))
	})

	fmt.Println("Server is running on port 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
