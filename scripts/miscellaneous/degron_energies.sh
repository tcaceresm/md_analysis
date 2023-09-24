#!/usr/bin/sh


find . -type f -name *_statistics.out -exec tail -n 1 {} \; > ../degron_energies.txt
