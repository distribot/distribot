#!/bin/bash -e

sudo chown -R ubuntu:ubuntu ./
bundle
foreman start
