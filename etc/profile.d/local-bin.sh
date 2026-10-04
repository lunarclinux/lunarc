# Put ~/.local/bin on PATH: per-user installers (Claude Code and others) use it.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
