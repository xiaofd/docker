package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", HelloServer)
	http.ListenAndServe("localhost:60003", nil)
	//http.ListenAndServeTLS("localhost:60003", "/etc/xray/xray.crt", "/etc/xray/xray.key", nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, %s!", r.URL.Path[1:])
}
