class_name UsernameWords
extends RefCounted

## Words a generated username is built from: one adjective + one animal + two digits ("HappyCat27").
## Removing or renaming a word locks out the accounts that use it, so only ever add words.

const ADJECTIVES: Array[String] = [
	"Happy", "Sunny", "Brave", "Clever", "Gentle", "Jolly", "Lucky", "Mighty", "Speedy", "Fluffy",
	"Bouncy", "Cheery", "Cosmic", "Daring", "Fuzzy", "Giggly", "Kind", "Merry", "Shiny", "Swift",
]
const ANIMALS: Array[String] = [
	"Cat", "Dog", "Fox", "Owl", "Bear", "Lion", "Tiger", "Panda", "Koala", "Otter",
	"Bunny", "Whale", "Zebra", "Horse", "Mouse", "Duck", "Frog", "Seal", "Deer", "Hippo",
]
