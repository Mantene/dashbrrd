# dashbrrd

A native iOS & iPadOS dashboard and management client for self-hosted **\*arr** services and their
download clients.

dashbrrd connects to the services running on your network and gives you one place to monitor and
manage them — browse libraries, add and search titles, control download queues, and see what's
coming up.

## Supported services (v1)

| Category | Services |
|---|---|
| Media libraries | Sonarr, Radarr, Lidarr, Readarr |
| Indexers | Prowlarr |
| Download clients | SABnzbd, NZBGet, qBittorrent, Transmission |
| Subtitles | Bazarr |

## Features

- **Dashboard** — at-a-glance status cards for every configured instance (version, queue size,
  health warnings, active downloads).
- **Services** — browse each media library, view details, toggle monitoring, trigger a manual
  search, add new titles via lookup, and remove items. iPad uses a sidebar + detail split layout.
- **Activity** — a unified view of every download queue and *arr activity across all instances.
- **Calendar** — upcoming releases from Sonarr and Radarr, grouped by day.
- **Connections** — add instances with a live **Test Connection** probe. API keys and passwords are
  stored in the iOS **Keychain**; the rest of the configuration is stored locally as JSON.

## Architecture

- **SwiftUI**, iOS/iPadOS 17+, no third-party dependencies.
- A per-instance `APIClient` actor with a pluggable `Authenticator` handles the different auth
  schemes each service uses (API-key header/query, HTTP Basic, the qBittorrent cookie login, and the
  Transmission session-id handshake).
- The five *arr apps share a `ServarrClient`; the media libraries are one config-driven
  `ServarrLibraryService` that round-trips raw JSON so adds/edits preserve every server field.
- Download clients share a unified `DownloadItem` / `DownloadClient` abstraction.

```
Views -> ViewModels -> Service clients -> APIClient(actor) -> Authenticator -> your servers
                                              ^                      |
                                   ConfigStore (JSON)         KeychainStore (secrets)
```

## Building

1. Open `dashbrrd.xcodeproj` in **Xcode 16 or newer** (the project uses file-system-synchronized
   groups, which require Xcode 16+).
2. Select the **dashbrrd** scheme and an iOS 17+ simulator or device, then **Run** (Cmd-R).
3. Run the unit tests with **Cmd-U** — they cover request building, the authenticators, and response
   decoding with no live server required.

On first launch, open **Settings -> Services -> +** to add an instance, fill in host/port and the API
key (or username/password), and tap **Test Connection**.

> Self-hosted services often run over plain HTTP or self-signed HTTPS on your LAN. dashbrrd allows
> local networking; for a self-signed HTTPS server, enable **Allow insecure TLS** on that instance.
