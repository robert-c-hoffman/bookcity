# Shelfarr

A self-hosted book and audiobook request system for the *arr ecosystem. Shelfarr combines a Jellyseerr-style request UI with Radarr/Sonarr-style acquisition and post-processing, specifically designed to work with Audiobookshelf.

## The Problem

The video stack has a mature pipeline: Jellyseerr → Sonarr/Radarr → Jellyfin. For books, only the library layer exists (Audiobookshelf). Shelfarr fills the gap by providing:

- **Request UI** — Family members can browse and request books
- **Metadata search** — Via Open Library API
- **Acquisition** — Through Prowlarr indexers
- **Download management** — Via qBittorrent (or other clients)
- **Post-processing** — Rename, organize, and deliver to Audiobookshelf

## Features

### For Users
- **Search & Request** — Browse Open Library, request audiobooks or ebooks
- **Library** — View acquired books and download directly
- **Notifications** — Get notified when requests complete or need attention
- **Profile** — Manage account settings and change password

### For Admins
- **Request Management** — Review search results, select downloads, monitor progress
- **Issues Dashboard** — Handle failed requests with bulk retry/cancel operations
- **User Management** — Create and manage user accounts
- **Download Clients** — Configure qBittorrent, SABnzbd, or other clients
- **System Health** — Monitor Prowlarr, download clients, and Audiobookshelf connectivity
- **Activity Log** — Audit trail of user and system actions
- **Settings** — Configure API keys, output paths, retry policies

### Technical
- Open Library integration for book metadata and covers
- Prowlarr integration for indexer searches
- Multiple download client support (qBittorrent, SABnzbd)
- Automatic file organization for Audiobookshelf compatibility
- Request queue with exponential backoff retry logic
- Multi-user support with role-based access (user/admin)
- Single Docker container deployment with SQLite
- Background job processing with Solid Queue (no Redis required)

## Requirements

- Ruby 3.3+ (for local development)
- Docker (for production deployment)
- Prowlarr (for indexer access)
- qBittorrent or similar download client
- Audiobookshelf (as the destination library)

## Quick Start

### Development

```bash
# Install Ruby 3.3.6 via rbenv (if needed)
brew install rbenv ruby-build
rbenv install 3.3.6

# Clone and setup
git clone https://github.com/yourusername/shelfarr.git
cd shelfarr
bundle install
bin/rails db:setup

# Start the development server
bin/dev
```

Visit http://localhost:3000 and create your account. The first user automatically becomes an admin.

**Development credentials (from seeds):**
- Email: `admin@shelfarr.local`
- Password: `password123`

### Docker

```bash
# Build the image
docker build -t shelfarr .

# Run with docker-compose
docker-compose up -d
```

Edit `docker-compose.yml` to configure your volume mounts:

```yaml
volumes:
  - ./data/storage:/rails/storage          # Database persistence
  - /path/to/your/audiobooks:/audiobooks   # Audiobookshelf audiobooks folder
  - /path/to/your/ebooks:/ebooks           # Audiobookshelf ebooks folder
```

You'll need to set `RAILS_MASTER_KEY` from `config/master.key` or generate a new `SECRET_KEY_BASE`.

## Configuration

After logging in as an admin, go to **Admin → Settings** to configure:

| Setting | Description |
|---------|-------------|
| Prowlarr URL | Base URL for your Prowlarr instance |
| Prowlarr API Key | API key from Prowlarr Settings → General |
| Download Client URL | Base URL for qBittorrent WebUI |
| Download Client Username/Password | Authentication credentials |
| Audiobook Output Path | Where to place completed audiobooks |
| Ebook Output Path | Where to place completed ebooks |

## File Organization

Shelfarr organizes files for Audiobookshelf compatibility:

```
/audiobooks
  /Author Name
    /Book Title
      /Book Title.m4b

/ebooks
  /Author Name
    /Book Title.epub
```

## Architecture

- **Framework**: Rails 8 with Hotwire (Turbo + Stimulus)
- **Database**: SQLite (single file, easy backup)
- **Background Jobs**: Solid Queue (no Redis required)
- **Styling**: Tailwind CSS

## Development

```bash
bin/dev              # Start server + Tailwind watcher
bin/rails test       # Run tests
bin/rails db:migrate # Run pending migrations
bin/jobs             # Start background job worker
```

## Roadmap

- [x] **Phase 1: Foundation** — Rails setup, auth, models, settings, Docker
- [x] **Phase 2: Metadata** — Open Library client, search, caching
- [x] **Phase 3: Requests** — Request flow, queue, retry logic
- [x] **Phase 4: Acquisition** — Prowlarr client, result selection, downloads
- [x] **Phase 5: Processing** — Download monitoring, post-processing, delivery
- [x] **Phase 6: Admin & Health** — Issues page, health monitoring, bulk operations
- [x] **Phase 7: Polish** — Dashboard, responsive layout, error handling
- [x] **Phase 8: Ecosystem** — Multiple download clients (qBittorrent, SABnzbd), in-app notifications, activity logging

## License

[MIT License](LICENSE)
