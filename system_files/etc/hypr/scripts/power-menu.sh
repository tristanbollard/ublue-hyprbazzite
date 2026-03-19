#!/bin/bash

SELECTION=$(echo -e "  Shutdown\n  Reboot\n  Logout\n  Lock\n  Suspend\n⏾  Hibernate\n  Eco TDP\n  Balanced TDP\n  Performance TDP" | wofi --dmenu --conf /etc/wofi/config --style /etc/wofi/style.css --width 250 --height 300 --prompt "Power Menu")

esac
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
	"⏾  Hibernate")
		systemctl hibernate
		;;
	"  Eco TDP")
		/etc/hypr/scripts/tdp-control.sh profile eco | wofi --dmenu --conf /etc/wofi/config --style /etc/wofi/style.css --width 400 --height 100 --prompt "Eco TDP Set" || true
		;;
	"  Balanced TDP")
		/etc/hypr/scripts/tdp-control.sh profile balanced | wofi --dmenu --conf /etc/wofi/config --style /etc/wofi/style.css --width 400 --height 100 --prompt "Balanced TDP Set" || true
		;;
	"  Performance TDP")
		/etc/hypr/scripts/tdp-control.sh profile performance | wofi --dmenu --conf /etc/wofi/config --style /etc/wofi/style.css --width 400 --height 100 --prompt "Performance TDP Set" || true
		;;
