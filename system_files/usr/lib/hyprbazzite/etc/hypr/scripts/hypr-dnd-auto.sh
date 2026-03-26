#!/bin/bash
# Monitor Hyprland socket for fullscreen events and toggle SwayNC DND

handle() {
  case $1 in
    fullscreen\>\>1)
        swaync-client --dnd-on
        ;;
    fullscreen\>\>0)
        swaync-client --dnd-off
        ;;
  esac
}

socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
