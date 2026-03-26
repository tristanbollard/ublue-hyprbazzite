#!/bin/bash

SELECTION=$(echo -e "  Shutdown\n  Reboot\n  Logout\n  Lock\n  Suspend\n⏾  Hybrid Sleep" | wofi --dmenu --conf /etc/wofi/config --style /etc/wofi/style.css --width 250 --height 300 --prompt "Power Menu")

case "$SELECTION" in
	"  Shutdown")
		systemctl poweroff
		;;
	"  Reboot")
		systemctl reboot
		;;
	"  Logout")
		hyprctl dispatch exit
		;;
	"  Lock")
		hyprlock
		;;
	"  Suspend")
		systemctl suspend
		;;
	"⏾  Hybrid Sleep")
		systemctl suspend-then-hibernate
		;;
	esac
