package main

import (
	"log"
	"net/http"
	"os"

	"github.com/garethmaybery/letsyak-vault-api/internal/api"
	"github.com/garethmaybery/letsyak-vault-api/internal/storage"
	"github.com/garethmaybery/letsyak-vault-api/internal/auth"
	"github.com/garethmaybery/letsyak-vault-api/internal/db"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func main() {
	port := envOrDefault("PORT", "8090")
	minioEndpoint := envOrDefault("MINIO_ENDPOINT", "localhost:9000")
	minioAccessKey := envOrDefault("MINIO_ACCESS_KEY", "letsyak-admin")
	minioSecretKey := envOrDefault("MINIO_SECRET_KEY", "changeme")
	minioUseSSL := os.Getenv("MINIO_USE_SSL") == "true"
	synapseURL := envOrDefault("SYNAPSE_URL", "http://localhost:8008")
	databaseURL := envOrDefault("DATABASE_URL", "postgres://localhost:5432/vault?sslmode=disable")
	publicURL := envOrDefault("VAULT_PUBLIC_URL", "http://localhost:8090")

	// Initialize MinIO storage client
	store, err := storage.New(minioEndpoint, minioAccessKey, minioSecretKey, minioUseSSL)
	if err != nil {
		log.Fatalf("Failed to initialize MinIO client: %v", err)
	}

	// Initialize database
	database, err := db.New(databaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.Close()

	if err := database.Migrate(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize auth (Matrix token validator)
	authenticator := auth.New(synapseURL)

	// Set up HTTP server
	handler := api.NewHandler(store, database, authenticator, publicURL)

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RealIP)

	// API routes — all require Matrix auth
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(handler.AuthMiddleware)

		r.Post("/auth/provision", handler.Provision)
		r.Get("/quota", handler.GetQuota)

		r.Get("/files", handler.ListFiles)
		r.Post("/files/upload-url", handler.GetUploadURL)
		r.Post("/files/download-url", handler.GetDownloadURL)
		r.Post("/files/folder", handler.CreateFolder)
		r.Delete("/files", handler.DeleteFile)
		r.Post("/files/move", handler.MoveFile)

		r.Post("/shares", handler.CreateShare)
		r.Get("/shares/{shareID}", handler.GetShare)
		r.Get("/shares/{shareID}/download", handler.DownloadShare)
		r.Delete("/shares/{shareID}", handler.RevokeShare)
		r.Get("/shares/mine", handler.ListMyShares)
	})

	// Public share download page (no auth)
	r.Get("/share/{shareID}", handler.PublicSharePage)

	log.Printf("LetsYak Vault API listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
