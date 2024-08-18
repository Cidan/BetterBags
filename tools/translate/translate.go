package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"encoding/json"

	"github.com/sashabaranov/go-openai"
)

type Translation struct {
	Locale string
	Text   string
}

type TranslationSet struct {
	Term         string
	Translations []Translation
}

var ignore_dirs = []string{".git", "libs", "tools"}
var toTranslate = []string{}

// Look for any string inside of a function call that looks like: L:G("string") or L:G('string')
var translationMatch = regexp.MustCompile(`L:G\(["'](.+?)["']\)`)

// removeDuplicates removes duplicate elements from a slice of strings.
// it also reads the term elements in cache/translations.json and removes them from the slice
func removeDuplicates(elements []string) []string {
	// Use map to record duplicates as we find them.
	encountered := map[string]bool{}
	// Create a slice for the keys.
	result := []string{}

	for v := range elements {
		if encountered[elements[v]] {
			// Do not add duplicate.
		} else {
			encountered[elements[v]] = true
		}
	}

	if _, err := os.Stat("cache/translations.json"); err == nil {
		// Read the term elements from cache/translations.json
		termFile, err := os.ReadFile("cache/translations.json")
		if err != nil {
			panic(err)
		}
		var termElements []TranslationSet
		if err := json.Unmarshal(termFile, &termElements); err != nil {
			panic(err)
		}
		// Remove the term elements from the map
		for _, term := range termElements {
			delete(encountered, term.Term)
		}
	}
	// Append the remaining elements to the result slice
	for k := range encountered {
		result = append(result, k)
	}
	return result
}

func readFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	data, err := io.ReadAll(f)
	if err != nil {
		return err
	}
	matches := translationMatch.FindAllSubmatch(data, -1)
	for _, match := range matches {
		toTranslate = append(toTranslate, string(match[1]))
	}
	return nil
}

func toPtr[T any](v T) *T {
	return &v
}

func main() {
	err := filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		for _, dir := range ignore_dirs {
			if strings.HasPrefix(path, dir) {
				return nil
			}
		}
		if !strings.HasSuffix(path, ".lua") {
			return nil
		}
		return readFile(path)
	})

	if err != nil {
		panic(err)
	}
	toTranslate = removeDuplicates(toTranslate)
	var inputs = make([]string, 30)
	var outputs []string
	for i, s := range toTranslate {
		inputs[i%30] += s + "\n"
	}

	key := os.Getenv("OPENAI_API_KEY")
	client := openai.NewClient(key)

	for i, input := range inputs {
		if input == "" {
			break
		}
		resp, err := client.CreateChatCompletion(
			context.Background(),
			openai.ChatCompletionRequest{
				Model: openai.GPT4o,
				Seed:  toPtr(8472),
				ResponseFormat: &openai.ChatCompletionResponseFormat{
					Type: openai.ChatCompletionResponseFormatTypeJSONObject,
				},
				Messages: []openai.ChatCompletionMessage{
					{
						Role: openai.ChatMessageRoleSystem,
						Content: `You are translation bot for World of Warcraft. You are to translate strings that are provided to you, one string per line,
							into the languages provided. You must keep in mind the context of World of Warcraft and translate the strings within the context
							of the game, taking care to understand the nuance of game specific lingo. All inputs are in American English.
							It's important that you are consistent with the translations, so that the same string is translated the same way across all languages.
							You must also be consistent with the capitalization of the strings. If the input string is in all caps, the output must also be in all caps, etc.
							You must also be consistent with punctuation. If the input string has a period at the end, the output must also have a period at the end.
							You must also be consistent within the language itself, for example, opposite values or meanings must be translated in a consistent way.
							You are to output a JSON map with each key being input text. The value for each key is a JSON object, with a key for each language country code,
							and the translated string as the value for the given country code.
							The strings need to be translated into the following country codes:
							koKR - Korean
							frFR - French
							deDE - German
							zhCN - Chinese (Simplified)
							esES - Spanish (Spain)
							zhTW - Chinese (Traditional)
							esMX - Spanish (Mexico)
							ruRU - Russian
							ptBR - Portuguese (Brazil)
							itIT - Italian`,
					},
					{
						Role:    openai.ChatMessageRoleUser,
						Content: input,
					},
				},
			},
		)
		if err != nil {
			panic(err)
		}
		outputs = append(outputs, resp.Choices[0].Message.Content)
		fmt.Printf("Processed chunk %d (%d/%d)\n", i, i+1, len(inputs))
	}
	var luaOutput = `local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

--[[
	THIS FILE IS AUTOGENERATED. DO NOT EDIT THIS FILE DIRECTLY.
	IF YOU NEED TO MODIFY A TRANSLATION, PLEASE EDIT overrides.lua!
]]--

`

	var sets []TranslationSet

	if _, err := os.Stat("cache/translations.json"); err == nil {
		termFile, err := os.ReadFile("cache/translations.json")
		if err != nil {
			panic(err)
		}
		if err := json.Unmarshal(termFile, &sets); err != nil {
			panic(err)
		}
	}

	for _, s := range outputs {
		var translations map[string]map[string]string
		if err := json.Unmarshal([]byte(s), &translations); err != nil {
			panic(err)
		}
		for term, translation := range translations {
			set := TranslationSet{Term: term}
			for locale, text := range translation {
				set.Translations = append(set.Translations, Translation{Locale: locale, Text: text})
			}
			sort.Slice(set.Translations, func(i, j int) bool {
				return set.Translations[i].Locale < set.Translations[j].Locale
			})
			sets = append(sets, set)
		}
	}
	sort.Slice(sets, func(i, j int) bool {
		return sets[i].Term < sets[j].Term
	})
	data, err := json.Marshal(&sets)
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile("cache/translations.json", data, 0644); err != nil {
		panic(err)
	}
	for _, set := range sets {
		luaOutput += fmt.Sprintf(`L.data["%s"] = {`, set.Term) + "\n"
		for _, translation := range set.Translations {
			luaOutput += fmt.Sprintf(`  ["%s"] = "%s",`, translation.Locale, translation.Text) + "\n"
		}
		luaOutput += "}\n"
	}
	if err := os.WriteFile("core/translations.lua", []byte(luaOutput), 0644); err != nil {
		panic(err)
	}
}
