# GCR ssh-agent Socket fix
if [ -z "$SSH_AUTH_SOCK" ] && [ -S "$XDG_RUNTIME_DIR/gcr/ssh" ]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
fi
