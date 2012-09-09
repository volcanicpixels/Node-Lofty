# Lofty

Lofty (named after the character from Bob The Builder) is a build script for WordPress plugins created using the Lava framework.

## Features
- Compiles, concatenates and minifies coffeescript
- Compiles, concatenates and minifies LESS
- Namespaces LAVA_ classes
- Plugin header creation (requires flag)

## Installation
    $ npm install -g lofty

## Configuration file
Lofty uses a configuration file (lofty.yml)
    
    name: Blank Plugin
    version: 1.0
    description: Blank Plugin - update configuration in lava.yaml
    url: http://www.google.com
    author: Daniel Chatfield
    author_url: http://www.volcanicpixels.com
    license: GPLv2
    class_namespace: Volcanic_Pixels_Blank_Plugin    

## Building
This creates a development build (no minifying) and puts it in the build directory.

    $ lofty

## Distribution builds
When you are ready to distribute this will create a copy in the dist folder.

    $ lofty -d

## Verbose messaging
    $ lofty -v