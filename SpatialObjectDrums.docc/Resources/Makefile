.PHONY: project clean install-magic-keyboard train-reference preview-docc sync-docc-code validate

project:
	./Scripts/generate_project.sh

clean:
	rm -rf SpatialObjectDrums.xcodeproj .build DerivedData

install-magic-keyboard:
	./Scripts/install_magic_keyboard_referenceobject.sh

train-reference:
	./Scripts/train_reference_object.sh --help

preview-docc:
	./Scripts/preview_docc.sh

sync-docc-code:
	./Scripts/generate_docc_highlights.py

validate:
	./Scripts/validate.sh
