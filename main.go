package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "MY_SECRET=%s", os.Getenv("MY_SECRET"))
	})

	http.ListenAndServe(":8080", nil)
}
