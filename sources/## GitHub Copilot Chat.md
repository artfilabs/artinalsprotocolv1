## GitHub Copilot Chat

- Extension Version: 0.22.2 (prod)
- VS Code: vscode/1.95.1
- OS: Mac

## Network

User Settings:
```json
  "github.copilot.advanced": {
    "debug.useElectronFetcher": true,
    "debug.useNodeFetcher": false
  }
```

Connecting to https://api.github.com:
- DNS ipv4 Lookup: 20.207.73.85 (90 ms)
- DNS ipv6 Lookup: ::ffff:20.207.73.85 (14 ms)
- Electron Fetcher (configured): HTTP 200 (477 ms)
- Node Fetcher: HTTP 200 (96 ms)
- Helix Fetcher: HTTP 200 (346 ms)

Connecting to https://api.individual.githubcopilot.com/_ping:
- DNS ipv4 Lookup: 140.82.112.21 (22 ms)
- DNS ipv6 Lookup: ::ffff:140.82.112.21 (0 ms)
- Electron Fetcher (configured): HTTP 200 (267 ms)
- Node Fetcher: HTTP 200 (806 ms)
- Helix Fetcher: HTTP 200 (847 ms)

## Documentation

In corporate networks: [Troubleshooting firewall settings for GitHub Copilot](https://docs.github.com/en/copilot/troubleshooting-github-copilot/troubleshooting-firewall-settings-for-github-copilot).