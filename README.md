# TGSEND
TG_Send - Bash script to send messages and files via Telegram Bot API with robust error handling and logging. Requires curl, jq, and file for seamless integration into automated workflows.

## Features

- 📨 Send text messages (supports Markdown formatting)
- 📁 Upload files (up to Telegram's 50MB limit)
- ✅ Automatic file type detection
- 🔒 Secure credential validation
- 📝 Comprehensive logging system
- 🚦 Error handling with status feedback

## Requirements

- `bash` (v4.0+)
- `curl`
- `jq`
- `file` utility

## Installation

1. Clone this repository:
```bash
git clone https://github.com/AdV1PeR/tgsend.git
cd tgsend
```

2. Edit the configuration section in `tgsend.sh`:
```bash
declare -r BOT_TOKEN="your_bot_token_here"
declare -r CHAT_ID="your_chat_id_here"
```

3. Make the script executable:
```bash
chmod +x tgsend.sh
```
Here's an improved README.md with installation to `/usr/local/bin`:

# Telegram Bot CLI

A lightweight Bash script for sending messages and files through Telegram Bot API.

## Features

- Send text messages (Markdown supported)
- Upload files (up to 50MB)
- Automatic MIME-type detection
- Error handling and logging

## Requirements

- Bash 4.0+
- `curl`, `jq`, `file` utilities

## Installation

1. Clone and install system-wide:

```bash
sudo curl -o /usr/local/bin/tgsend https://raw.githubusercontent.com/yourusername/telegram-bot-cli/main/tgsend.sh
sudo chmod +x /usr/local/bin/tgsend
```

2. Create config file:

```bash
mkdir -p ~/.config/tgsend
echo 'BOT_TOKEN="your_bot_token_here"' > ~/.config/tgsend/config
echo 'CHAT_ID="your_chat_id_here"' >> ~/.config/tgsend/config
chmod 600 ~/.config/tgsend/config
```

## Usage

```bash
tgsend -m "Hello World"  # Send message
tgsend -f file.pdf       # Send file
tgsend -h                # Show help
```

### Send:
```bash
./tgsend.sh "Hello from Telegram Bot CLI"
./tgsend.sh <filename>
```

## Logging

All operations are logged to:
```
~/.local/log/tgsend/tgsend.log
```

## License

MIT License

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---
