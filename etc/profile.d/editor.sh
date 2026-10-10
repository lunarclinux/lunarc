# Default editor for shells outside the desktop session (TTY, SSH); the
# session gets it from environment.d. Anything already set wins.
export EDITOR=${EDITOR:-micro}
export VISUAL=${VISUAL:-$EDITOR}
export MICRO_TRUECOLOR=${MICRO_TRUECOLOR:-1}
