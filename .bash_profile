# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs
. "$HOME/.cargo/env"

export FLYCTL_INSTALL="/home/priax/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"
