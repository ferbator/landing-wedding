const rsvpForm = document.querySelector("[data-rsvp-form]");
const formStatus = document.querySelector("[data-form-status]");
const submissionFrame = document.querySelector(".submission-frame");
let formWasSubmitted = false;

if (rsvpForm && formStatus && submissionFrame) {
  const submitButton = rsvpForm.querySelector('[type="submit"]');
  const submitButtonText = submitButton ? submitButton.textContent : "";
  let focusedInvalidField = false;

  const setFormLoading = (isLoading) => {
    if (!submitButton) {
      return;
    }

    submitButton.disabled = isLoading;
    submitButton.textContent = isLoading ? "Отправляем…" : submitButtonText;
  };

  const clearFieldErrors = () => {
    rsvpForm.querySelectorAll("[aria-invalid]").forEach((field) => {
      field.removeAttribute("aria-invalid");
    });

    rsvpForm.querySelectorAll("[data-field-error]").forEach((error) => {
      error.textContent = "";
    });
  };

  const showFieldError = (field) => {
    field.setAttribute("aria-invalid", "true");

    const errorId = field.getAttribute("aria-describedby");
    const errorElement = errorId ? document.getElementById(errorId) : null;

    if (errorElement) {
      errorElement.textContent = "Заполните это поле.";
    }
  };

  const showGroupError = (group) => {
    group.setAttribute("aria-invalid", "true");

    const errorId = group.getAttribute("aria-describedby");
    const errorElement = errorId ? document.getElementById(errorId) : null;

    if (errorElement) {
      errorElement.textContent = "Выберите хотя бы один вариант.";
    }
  };

  const validateRequiredGroups = () => {
    const invalidGroup = [...rsvpForm.querySelectorAll("[data-required-group]")].find((group) => {
      return !group.querySelector('input[type="checkbox"]:checked');
    });

    if (!invalidGroup) {
      return null;
    }

    showGroupError(invalidGroup);
    return invalidGroup.querySelector('input[type="checkbox"]');
  };

  const clearFieldError = (field) => {
    const relatedFields = field.name
      ? rsvpForm.querySelectorAll(`[name="${CSS.escape(field.name)}"]`)
      : [field];

    relatedFields.forEach((relatedField) => {
      relatedField.removeAttribute("aria-invalid");
    });

    const errorId = field.getAttribute("aria-describedby");
    const errorElement = errorId ? document.getElementById(errorId) : null;

    if (errorElement) {
      errorElement.textContent = "";
    }

    const group = field.closest("[data-required-group]");

    if (group) {
      group.removeAttribute("aria-invalid");

      const groupErrorId = group.getAttribute("aria-describedby");
      const groupErrorElement = groupErrorId ? document.getElementById(groupErrorId) : null;

      if (groupErrorElement) {
        groupErrorElement.textContent = "";
      }
    }
  };

  const focusInvalidField = (field) => {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    field.focus({ preventScroll: true });
    field.scrollIntoView({ block: "center", behavior: prefersReducedMotion ? "auto" : "smooth" });
  };

  if (submitButton) {
    submitButton.addEventListener("click", () => {
      focusedInvalidField = false;
      clearFieldErrors();
    });
  }

  rsvpForm.addEventListener("submit", (event) => {
    clearFieldErrors();
    const firstInvalidGroupField = validateRequiredGroups();

    if (!rsvpForm.checkValidity() || firstInvalidGroupField) {
      event.preventDefault();

      const firstInvalidField = rsvpForm.querySelector(":invalid") || firstInvalidGroupField;

      if (firstInvalidField) {
        showFieldError(firstInvalidField);
        focusInvalidField(firstInvalidField);
      }

      formWasSubmitted = false;
      formStatus.textContent = "Пожалуйста, заполните обязательные поля.";
      return;
    }

    formWasSubmitted = true;
    setFormLoading(true);
    formStatus.textContent = "Отправляем ответ…";
  });

  rsvpForm.addEventListener(
    "invalid",
    (event) => {
      formWasSubmitted = false;
      showFieldError(event.target);

      if (!focusedInvalidField) {
        focusedInvalidField = true;
        focusInvalidField(event.target);
      }

      formStatus.textContent = "Пожалуйста, заполните обязательные поля.";
    },
    true
  );

  rsvpForm.addEventListener("reset", () => {
    formWasSubmitted = false;
    setFormLoading(false);
    clearFieldErrors();
    formStatus.textContent = "";
  });

  rsvpForm.addEventListener("input", (event) => {
    if (event.target.matches("[data-other-choice-input]")) {
      const group = event.target.closest(".choice-group");
      const otherChoice = group ? group.querySelector("[data-other-choice]") : null;

      if (otherChoice && event.target.value.trim()) {
        otherChoice.checked = true;
      }
    }

    clearFieldError(event.target);
  });

  rsvpForm.addEventListener("change", (event) => {
    if (event.target.matches("[data-other-choice]") && !event.target.checked) {
      const group = event.target.closest(".choice-group");
      const otherInput = group ? group.querySelector("[data-other-choice-input]") : null;

      if (otherInput) {
        otherInput.value = "";
      }
    }

    clearFieldError(event.target);
  });

  submissionFrame.addEventListener("load", () => {
    if (!formWasSubmitted) {
      return;
    }

    formWasSubmitted = false;
    setFormLoading(false);
    rsvpForm.reset();
    formStatus.textContent = "Спасибо, ответ отправлен.";
  });
}

document.querySelectorAll("[data-date-format]").forEach((element) => {
  const date = new Date(`${element.dateTime}T00:00:00`);
  const format = element.dataset.dateFormat === "short"
    ? { day: "2-digit", month: "2-digit", year: "2-digit" }
    : { day: "numeric", month: "long", year: "numeric" };

  element.textContent = new Intl.DateTimeFormat("ru-RU", format).format(date);
});

if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.14, rootMargin: "0px 0px -8% 0px" }
  );

  document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));
} else {
  document.querySelectorAll(".reveal").forEach((element) => {
    element.classList.add("is-visible");
  });
}
