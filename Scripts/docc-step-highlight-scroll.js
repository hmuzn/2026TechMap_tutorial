(() => {
    "use strict";

    const activationRatio = 0.35;
    const previewSelector = ".asset-container.for-step-code .code-preview";
    const highlightedLineSelector = ".code-line-container.highlighted";
    const handledStates = new WeakMap();
    let firstFrame = 0;
    let secondFrame = 0;
    let revision = 0;

    function highlightSignature(preview, lines) {
        const fileName = preview.querySelector(".filename")?.textContent?.trim() ?? "";
        const allLines = Array.from(preview.querySelectorAll(".code-line-container"));
        const codeContent = allLines.map((line) => {
            const number = line.querySelector(".code-number")
                ?.getAttribute("data-line-number") ?? "";
            return `${number}:${line.textContent ?? ""}`;
        }).join("\n");
        const highlightedContent = lines.map((line) => (
            line.querySelector(".code-number")?.getAttribute("data-line-number") ?? ""
        )).join(",");
        return `${fileName}:${preview.clientWidth}:${preview.clientHeight}`
            + `\n${codeContent}\n${highlightedContent}`;
    }

    function activeContext() {
        const activationLine = window.innerHeight * activationRatio;
        const candidates = Array.from(document.querySelectorAll(".steps"))
            .map((steps) => {
                const rect = steps.getBoundingClientRect();
                return { steps, rect };
            })
            .filter(({ rect }) => (
                rect.top <= activationLine && rect.bottom >= activationLine
            ));

        const steps = candidates[0]?.steps;
        if (!steps) {
            return null;
        }

        const focusedStep = steps.querySelector(".step.focused[data-index]");
        const preview = steps.querySelector(previewSelector);
        const previewRect = preview?.getBoundingClientRect();
        if (
            !focusedStep
            || !preview
            || preview.clientHeight === 0
            || previewRect.bottom <= 0
            || previewRect.top >= window.innerHeight
        ) {
            return null;
        }

        return {
            steps,
            focusedStep,
            preview,
            stepIndex: focusedStep.getAttribute("data-index") ?? "",
        };
    }

    function revealCurrentHighlights() {
        const context = activeContext();
        if (!context) {
            return;
        }

        const { focusedStep, preview, stepIndex } = context;
        const highlightedLines = Array.from(
            preview.querySelectorAll(highlightedLineSelector)
        );
        const signature = `${stepIndex}\n${highlightSignature(preview, highlightedLines)}`;
        if (handledStates.get(preview) === signature) {
            return;
        }

        if (!focusedStep.isConnected || !preview.isConnected) {
            scheduleReveal();
            return;
        }

        if (highlightedLines.length === 0) {
            preview.scrollTo({ top: 0, behavior: "auto" });
            handledStates.set(preview, signature);
            return;
        }

        const firstHighlight = highlightedLines[0];
        const lastHighlight = highlightedLines[highlightedLines.length - 1];
        const previewRect = preview.getBoundingClientRect();
        const firstRect = firstHighlight.getBoundingClientRect();
        const lastRect = lastHighlight.getBoundingClientRect();
        const inset = Math.min(96, Math.max(24, preview.clientHeight * 0.2));
        const comfortTop = previewRect.top + inset;
        const comfortBottom = previewRect.bottom - inset;

        let delta = 0;
        if (firstRect.top < comfortTop || lastRect.bottom > comfortBottom) {
            const rangeHeight = lastRect.bottom - firstRect.top;
            const comfortHeight = comfortBottom - comfortTop;
            if (firstRect.top < comfortTop || rangeHeight > comfortHeight) {
                delta = firstRect.top - comfortTop;
            } else {
                delta = lastRect.bottom - comfortBottom;
            }
        }

        if (delta !== 0) {
            preview.scrollTo({
                top: Math.max(0, preview.scrollTop + delta),
                behavior: "auto",
            });
        }
        handledStates.set(preview, signature);
    }

    function scheduleReveal() {
        revision += 1;
        const scheduledRevision = revision;
        if (firstFrame) {
            cancelAnimationFrame(firstFrame);
        }
        if (secondFrame) {
            cancelAnimationFrame(secondFrame);
        }

        firstFrame = requestAnimationFrame(() => {
            firstFrame = 0;
            secondFrame = requestAnimationFrame(() => {
                secondFrame = 0;
                if (scheduledRevision === revision) {
                    revealCurrentHighlights();
                }
            });
        });
    }

    function wheelDeltaInPixels(event) {
        if (event.deltaMode === 1) {
            return event.deltaY * 16;
        }
        if (event.deltaMode === 2) {
            return event.deltaY * window.innerHeight;
        }
        return event.deltaY;
    }

    function forwardCodePanelWheel(event) {
        if (
            event.defaultPrevented
            || event.ctrlKey
            || event.metaKey
            || event.shiftKey
            || Math.abs(event.deltaY) <= Math.abs(event.deltaX)
        ) {
            return;
        }

        const preview = event.target instanceof Element
            ? event.target.closest(previewSelector)
            : null;
        const context = activeContext();
        if (!preview || context?.preview !== preview) {
            return;
        }

        event.preventDefault();
        window.scrollBy({
            top: wheelDeltaInPixels(event),
            left: 0,
            behavior: "auto",
        });
    }

    function start() {
        document.documentElement.dataset.doccStepSync = "2";
        const root = document.getElementById("app") ?? document.body;
        const observer = new MutationObserver(scheduleReveal);
        observer.observe(root, {
            subtree: true,
            childList: true,
            characterData: true,
            attributes: true,
            attributeFilter: ["class", "data-line-number"],
        });
        window.addEventListener("scroll", scheduleReveal, { passive: true });
        window.addEventListener("resize", scheduleReveal, { passive: true });
        window.addEventListener("pageshow", scheduleReveal, { passive: true });
        document.addEventListener("wheel", forwardCodePanelWheel, {
            capture: true,
            passive: false,
        });
        document.fonts?.ready.then(scheduleReveal);
        scheduleReveal();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", start, { once: true });
    } else {
        start();
    }
})();
