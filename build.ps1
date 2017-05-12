param (
  [string] $cmd = $null
)

$REPO_PATH = "github.com/sensu/sensu-go"

# source in the environment variables from `go env`
$env_commands = go env
ForEach ($env_cmd in $env_commands) {
  $env_str = $env_cmd -replace "set " -replace ""
  $env = $env_str.Split("=")
  $ps_cmd = "`$env:$($env[0]) = ""$($env[1])"""
  Invoke-Expression $ps_cmd
}

$RACE = ""

function set_race_flag
{
  If ($env:GOARCH -eq "amd64") {
    $RACE = "-race"
  }
}

switch ($env:GOOS)
{
        "darwin" {set_race_flag}
        "freebsd" {set_race_flag}
        "linux" {set_race_flag}
        "windows" {set_race_flag}
}

function install_deps
{
  go get github.com/axw/gocov/gocov
  go get gopkg.in/alecthomas/gometalinter.v1
  go get github.com/gordonklaus/ineffassign
  go get github.com/jgautheron/goconst/cmd/goconst
  go get -u github.com/golang/lint/golint
}

function build_tool_binary([string]$goos, [string]$goarch, [string]$bin, [string]$subdir)
{
  $outfile = "target/$goos-$goarch/$subdir/$bin.exe"
  $env:GOOS = $goos
  $env:GOARCH = $goarch
  go build -i -o $outfile "$REPO_PATH/$subdir/$bin/..."
  If ($LASTEXITCODE -ne 0) {
    echo "Failed to build $outfile..."
    exit 1
  }

  return $outfile
}

function build_binary([string]$goos, [string]$goarch, [string]$bin)
{
  $outfile = "target/$goos-$goarch/sensu-$bin.exe"
  $env:GOOS = $goos
  $env:GOARCH = $goarch
  go build -i -o $outfile "$REPO_PATH/$bin/cmd/..."
  If ($LASTEXITCODE -ne 0) {
    echo "Failed to build $outfile..."
    exit 1
  }

  return $outfile
}

function build_tools
{
  echo "Running tool & plugin builds..."

  ForEach ($bin in "cat","false","sleep","true") {
    build_tool $bin "tools"
  }

  ForEach ($bin in "slack") {
    build_tool $bin "handlers"
  }
}

function build_tool([string]$bin, [string]$subdir)
{
  If (!(Test-Path -Path "bin/$subdir")) {
    New-Item -ItemType directory -Path "bin/$subdir" | out-null
  }

  echo "Building $subdir/$bin for $env:GOOS-$env:GOARCH"
  $out = build_tool_binary $env:GOOS $env:GOARCH $bin $subdir
  Remove-Item -Path "bin/$(Split-Path -Leaf $out)" -EA SilentlyContinue
  cp $out bin/$subdir
}

function build_commands
{
  echo "Running build..."

  ForEach ($bin in "agent","backend","cli") {
    build_command $bin
  }
}

function build_command([string]$bin)
{
  If (!(Test-Path -Path "bin")) {
    New-Item -ItemType directory -Path "bin" | out-null
  }

  echo "Building $bin for $env:GOOS-$env:GOARCH"
  $out = build_binary $env:GOOS $env:GOARCH $bin
  Remove-Item -Path "bin/$(Split-Path -Leaf $out)" -EA SilentlyContinue
  cp $out bin
}

function linter_commands
{
  echo "Running linter..."

  gometalinter.v1 --vendor --disable-all --enable=vet --linter='vet:go tool vet -composites=false {paths}:PATH:LINE:MESSAGE' --enable=vetshadow --enable=golint --enable=ineffassign --enable=goconst --tests ./...
  If ($LASTEXITCODE -ne 0) {
    echo "Linting failed..."
    exit 1
  }
}

function test_commands
{
  echo "Running tests..."

  $failed = 0
  echo "" > "coverage.txt"
  $packages = go list ./... | Select-String -pattern "testing", "vendor" -notMatch
  ForEach ($pkg in $packages) {
    go test -timeout=60s -v -coverprofile="profile.out" -covermode=atomic $pkg
    If ($LASTEXITCODE -ne 0) {
      $failed = 1
    }
    If (Test-Path "profile.out") {
      cat "profile.out" >> "coverage.txt"
      rm "profile.out"
    }
  }

  If ($failed -ne 0) {
    echo "Unit testing failed..."
    exit 1
  }
}

function e2e_commands
{
  echo "Running e2e tests..."

  go test -v $REPO_PATH/testing/e2e
  If ($LASTEXITCODE -ne 0) {
    echo "e2e testing failed..."
    exit 1
  }
}

If ($cmd -eq "deps") {
  install_deps
}
ElseIf ($cmd -eq "quality") {
  linter_commands
  test_commands
}
ElseIf ($cmd -eq "lint") {
  linter_commands
}
ElseIf ($cmd -eq "unit") {
  test_commands
}
ElseIf ($cmd -eq "build_tools") {
  build_tools
}
ElseIf ($cmd -eq "e2e") {
  e2e_commands
}
ElseIf ($cmd -eq "build") {
  build_commands
}
ElseIf ($cmd -eq "docker") {
  # no-op for now
}
ElseIf ($cmd -eq "build_agent") {
  build_command "agent"
}
ElseIf ($cmd -eq "build_backend") {
  build_command "backend"
}
ElseIf ($cmd -eq "build_cli") {
  build_command "cli"
}
Else {
  install_deps
  linter_commands
  build_tools
  test_commands
  build_commands
  e2e_commands
}