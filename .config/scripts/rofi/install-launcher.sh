#!/usr/bin/env bash
# Install Launcher - Opens rofi with INSTALL tab active
# Use this for Super+P keybind

rofi -no-lazy-grab \
     -show INSTALL \
     -theme "$HOME/.config/rofi/config.rasi"
