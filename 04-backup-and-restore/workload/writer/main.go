package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"log"
	"math/rand/v2"
	"time"

	_ "github.com/lib/pq"
)

const charset = "abcdefghijklmnopqrstuvwxyz0123456789"

func randomPayload() string {
	b := make([]byte, 36)
	for i := range b {
		b[i] = charset[rand.IntN(len(charset))]
	}
	return string(b)
}

func checksum(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

func main() {
	dsn := "host=/var/run/postgresql dbname=backuplab sslmode=disable"
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("open: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("ping: %v", err)
	}
	log.Println("writer connected to backuplab")

	stmt, err := db.Prepare("INSERT INTO events(payload, checksum) VALUES($1, $2) RETURNING id, written_at")
	if err != nil {
		log.Fatalf("prepare: %v", err)
	}
	defer stmt.Close()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		payload := randomPayload()
		sum := checksum(payload)

		var id int64
		var at time.Time
		if err := stmt.QueryRow(payload, sum).Scan(&id, &at); err != nil {
			log.Printf("insert error: %v", err)
			continue
		}
		log.Printf("inserted id=%d at=%s", id, at.Format(time.RFC3339))
	}
}
