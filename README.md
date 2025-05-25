# TGSend
TG_Send - Bash script to send messages and files via Telegram Bot API with robust error handling and logging. Requires curl, jq, and file for seamless integration into automated workflows.

## Features

- 📨 Send text messages (supports Markdown formatting)
- 📁 Upload files (up to Telegram's 50MB limit)
- ✅ Automatic file type detection
- 🔒 Secure credential validation
- 📝 Comprehensive logging system
- 🚦 Error handling with status feedback

## Requirements
- `bash`     `curl`   `jq`   `file`  `utility`

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
## Option 2: System-wide Installation (recommended)
  1. Add tgsend.sh to /usr/local/bin/
  ```bash
  sudo mv tgsend.sh /usr/local/bin
  sudo chmod +x tgsend.sh && mv tgsend.sh tgsend
  ```

### Send:
1. Non-System-wide:
```bash
./tgsend.sh "Hello from Telegram Bot CLI"
./tgsend.sh <filename>
```
2. System-wide:
```bash
tgsend "Hello from Telegram Bot CLI"
tgsend <filename>
```

## Logging

All operations are logged to:
```
~/.local/log/tgsend/tgsend.log
```

## License

MIT License, Copyright (c) 2025 AdV1PeR

---
