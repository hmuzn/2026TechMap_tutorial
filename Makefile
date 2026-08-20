.PHONY: project clean install-magic-keyboard train-iphone validate

project:
	xcodegen generate

clean:
	rm -rf SpatialObjectDrums.xcodeproj .build DerivedData

install-magic-keyboard:
	./Scripts/install_magic_keyboard_referenceobject.sh

train-iphone:
	./Scripts/train_iphone17.sh

validate:
	./Scripts/validate.sh
