# Zsh Configuration

Bộ cài đặt Zsh + Oh My Zsh với các plugin.

## Nội dung

- `.zshrc` - File cấu hình Zsh
- `setup.sh` - Script tự động cài đặt

## Cách sử dụng

```bash
chmod +x Zsh/setup.sh
./Zsh/setup.sh
```

## Script sẽ tự động:

1. Cài đặt **Zsh** (nếu chưa có)
2. Đặt Zsh làm **default shell**
3. Cài đặt **Oh My Zsh**
4. Cài đặt **fzf**
5. Cài đặt các **plugins**:
   - `git` (built-in)
   - `zsh-autosuggestions` (external)
   - `docker` (built-in)
   - `docker-compose` (built-in)
   - `history` (built-in)
   - `rsync` (built-in)
   - `safe-paste` (built-in)
   - `fzf` (built-in + binary)
   - `zsh-syntax-highlighting` (external)
6. Copy `.zshrc` vào `$HOME/.zshrc`

## Theme

- **strug**
