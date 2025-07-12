package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <directory>")
		os.Exit(1)
	}

	rootDir := os.Args[1]
	metaAnnotation := "---@meta"

	err := filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !info.IsDir() && strings.HasSuffix(info.Name(), ".lua") {
			file, err := os.Open(path)
			if err != nil {
				fmt.Printf("Error opening file %s: %v\n", path, err)
				return nil
			}
			defer file.Close()

			// Check if the first line is already the meta annotation
			scanner := bufio.NewScanner(file)
			if scanner.Scan() {
				if strings.TrimSpace(scanner.Text()) == metaAnnotation {
					// Already has the annotation, so we skip it.
					return nil
				}
			}

			// If we are here, it means the file does not have the annotation or is empty.
			// We need to read the whole file to prepend the annotation.
			file.Seek(0, 0) // Reset reader to the start of the file
			content, err := ioutil.ReadAll(file)
			if err != nil {
				fmt.Printf("Error reading file %s: %v\n", path, err)
				return nil
			}

			newContent := metaAnnotation + "\n" + string(content)
			err = ioutil.WriteFile(path, []byte(newContent), info.Mode())
			if err != nil {
				fmt.Printf("Error writing to file %s: %v\n", path, err)
				return nil
			}
			fmt.Printf("Added meta annotation to %s\n", path)
		}
		return nil
	})

	if err != nil {
		fmt.Printf("Error walking the path %q: %v\n", rootDir, err)
	}
}
