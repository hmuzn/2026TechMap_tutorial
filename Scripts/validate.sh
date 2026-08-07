#!/bin/sh
set -eu

required="README.md project.yml SpatialObjectDrums.docc/SpatialObjectDrums.tutorial SpatialObjectDrums.docc/Tutorials/01-Prepare.tutorial SpatialObjectDrums.docc/Tutorials/02-TrackObjects.tutorial SpatialObjectDrums.docc/Tutorials/03-PlayDrums.tutorial .github/workflows/deploy-docc.yml"
for file in $required; do
  test -f "$file" || { echo "missing: $file"; exit 1; }
done

grep -q 'DOCC_HOSTING_BASE_PATH: 2026TechMap_tutorial' project.yml
grep -q 'DOCC_HOSTING_BASE_PATH=2026TechMap_tutorial' .github/workflows/deploy-docc.yml
grep -q '@Tutorials' SpatialObjectDrums.docc/SpatialObjectDrums.tutorial
grep -q '@Tutorial' SpatialObjectDrums.docc/Tutorials/01-Prepare.tutorial

for resource in $(sed -n 's/.*file: "\([^"]*\)".*/\1/p' SpatialObjectDrums.docc/Tutorials/*.tutorial); do
  test -f "SpatialObjectDrums.docc/Resources/$resource" || { echo "missing DocC resource: $resource"; exit 1; }
done
echo "Repository structure and critical DocC references look valid."
