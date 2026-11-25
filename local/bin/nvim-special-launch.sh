#!/bin/bash
# Solo lanza si no hay servidor activo
if [[ ! -S /tmp/nvim-server ]]; then
    kitty --title nvim-special nvim --listen /tmp/nvim-server
else
    notify-send "nvim-special" "El servidor ya está activo (usa Ctrl+Shift+X solo una vez)"
fi

