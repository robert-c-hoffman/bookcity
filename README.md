# Shelfarr

A self-hosted ebook and audiobook request and management system for the *arr ecosystem.

**The missing piece**: The video stack has Jellyseerr + Sonarr/Radarr + Jellyfin. For books, only the library exists (Audiobookshelf). Shelfarr fills the gap—think Readarr meets Jellyseerr, but for books that actually works.

## What It Does

- **Request UI** — Users browse and request books via Open Library
- **Acquisition** — Searches Prowlarr indexers, downloads via qBittorrent/SABnzbd
- **Processing** — Organizes files and delivers to Audiobookshelf
- **Multi-user** — Role-based access with admin controls

## Quick Start

### Docker (Recommended)

```bash
# 1. Create directory and download compose file
mkdir shelfarr && cd shelfarr
curl -O https://raw.githubusercontent.com/Pedro-Revez-Silva/shelfarr/main/docker-compose.example.yml
mv docker-compose.example.yml docker-compose.yml

# 2. Generate a master key
echo "RAILS_MASTER_KEY=$(openssl rand -hex 32)" > .env

# 3. Edit docker-compose.yml with your paths
#    - /path/to/audiobooks → your Audiobookshelf audiobooks folder
#    - /path/to/ebooks → your Audiobookshelf ebooks folder
#    - /path/to/downloads → your download client's completed folder

# 4. Start
docker-compose up -d
```

Visit `http://localhost:3000` — the first user to register becomes admin.

### Configuration

After logging in, go to **Admin → Settings**:

| Setting | Description |
|---------|-------------|
| Prowlarr URL + API Key | For indexer searches |
| Download Client | qBittorrent or SABnzbd connection |
| Output Paths | Where to place completed audiobooks/ebooks |
| Audiobookshelf | URL + API key for library integration |

## Requirements

- Docker
- Prowlarr (indexer manager)
- qBittorrent or SABnzbd (download client)
- Audiobookshelf (destination library)

## Development

```bash
# Install Ruby 3.3.6 via rbenv
brew install rbenv ruby-build
rbenv install 3.3.6

# Clone and setup
git clone https://github.com/Pedro-Revez-Silva/shelfarr.git
cd shelfarr
bundle install
bin/rails db:setup

# Start development server
bin/dev
```

## License

[GPL-3.0](LICENSE)
