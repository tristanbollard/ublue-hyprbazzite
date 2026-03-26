# ===== BASE ENV =====
export QT_QPA_PLATFORMTHEME=qt5ct
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# ===== OH-MY-ZSH + STARSHIP =====
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
	git
	dnf
	z
	fzf
	sudo
	colored-man-pages
	command-not-found
)

if [ -r "$ZSH/oh-my-zsh.sh" ]; then
	source "$ZSH/oh-my-zsh.sh"
fi

if command -v starship >/dev/null 2>&1; then
	eval "$(starship init zsh)"
fi

# ===== FASTFETCH =====
if command -v fastfetch >/dev/null 2>&1; then
	fastfetch
fi

# ===== FZF =====
if command -v fzf >/dev/null 2>&1; then
	source <(fzf --zsh)
fi

# ===== ALIASES =====
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias s='kitten ssh'

# ===== SSH AGENT (BITWARDEN FLATPAK PREFERRED) =====
if [ -S "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock" ]; then
	export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
elif [ -z "${SSH_AUTH_SOCK:-}" ] && command -v ssh-agent >/dev/null 2>&1; then
	eval "$(ssh-agent -s)" >/dev/null 2>&1
fi

