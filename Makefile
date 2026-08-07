.PHONY: project clean validate

project:
	xcodegen generate

clean:
	rm -rf SpatialObjectDrums.xcodeproj .build DerivedData

validate:
	./Scripts/validate.sh

