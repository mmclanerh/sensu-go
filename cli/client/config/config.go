package config

import (
	"github.com/sensu/sensu-go/types"
)

const (
	// DefaultEdition represents the default Sensu edition
	DefaultEdition = types.CoreEdition
	// DefaultEnvironment represents the default environment
	DefaultEnvironment = "default"
	// DefaultFormat represents the default format output when displaying objects
	DefaultFormat = "tabular"
	// DefaultOrganization represents the default organization
	DefaultOrganization = "default"
	// FormatTabular represents the string for tabular format
	FormatTabular = "tabular"
	// FormatJSON represents the string for JSON format
	FormatJSON = "json"
	// FormatWrappedJSON represents the string for wrapped JSON format
	FormatWrappedJSON = "wrapped-json"
)

// Config represents an abstracted configuration
type Config interface {
	Read
	Write
}

// Read contains all methods related to reading configuration
type Read interface {
	APIUrl() string
	Edition() string
	Environment() string
	Format() string
	Organization() string
	Tokens() *types.Tokens
}

// Write contains all methods related to setting and writting configuration
type Write interface {
	SaveAPIUrl(string) error
	SaveEdition(string) error
	SaveEnvironment(string) error
	SaveFormat(string) error
	SaveOrganization(string) error
	SaveTokens(*types.Tokens) error
}
