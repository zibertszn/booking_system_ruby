(function () {
  function getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : "";
  }

  function initResourceImageUploader() {
    const mountEl = document.getElementById("vue-resource-image-uploader");
    if (!mountEl || !window.Vue) return;

    const { createApp, ref } = window.Vue;
    const resourceId = mountEl.dataset.resourceId;
    const initialImage = mountEl.dataset.currentImage || "/images/room_alpha.svg";
    const resourceName = mountEl.dataset.resourceName || "Ресурс";

    const app = createApp({
      setup() {
        const currentImage = ref(initialImage);
        const rawSource = ref("");
        const previewImage = ref("");
        const isEditing = ref(false);
        const isSaving = ref(false);
        const statusMsg = ref("");
        const errorMsg = ref("");
        const selectedFileName = ref("");

        function onFileChange(event) {
          const file = event.target.files && event.target.files[0];
          if (!file) return;
          errorMsg.value = "";
          statusMsg.value = "";
          selectedFileName.value = file.name;

          const reader = new FileReader();
          reader.onload = (e) => {
            rawSource.value = e.target.result;
            previewImage.value = e.target.result;
          };
          reader.readAsDataURL(file);
        }

        async function saveImage() {
          if (!previewImage.value) {
            errorMsg.value = "Выберите файл изображения с компьютера.";
            return;
          }

          isSaving.value = true;
          errorMsg.value = "";
          statusMsg.value = "";

          try {
            const response = await fetch(`/resources/${encodeURIComponent(resourceId)}/update_image`, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Accept: "application/json",
                "X-CSRF-Token": getCsrfToken()
              },
              body: JSON.stringify({
                image_data: previewImage.value.startsWith("data:image/") ? previewImage.value : ""
              })
            });

            const data = await response.json();
            if (!response.ok) {
              throw new Error(data.error || "Ошибка при сохранении изображения");
            }

            currentImage.value = data.image_url;
            rawSource.value = "";
            previewImage.value = "";
            selectedFileName.value = "";
            isEditing.value = false;
            statusMsg.value = "Фотография ресурса успешно сохранена.";
          } catch (err) {
            errorMsg.value = err.message || "Не удалось загрузить изображение";
          } finally {
            isSaving.value = false;
          }
        }

        function cancelEdit() {
          isEditing.value = false;
          rawSource.value = "";
          previewImage.value = "";
          selectedFileName.value = "";
          errorMsg.value = "";
        }

        return {
          resourceName,
          currentImage,
          previewImage,
          rawSource,
          isEditing,
          isSaving,
          statusMsg,
          errorMsg,
          selectedFileName,
          onFileChange,
          saveImage,
          cancelEdit
        };
      },
      template: `
        <div class="flex flex-col justify-between space-y-3 h-full">
          <div class="rounded-lg overflow-hidden bg-slate-900 border border-slate-200 h-64 sm:h-72 relative flex items-center justify-center p-2">
            <img
              :src="previewImage || currentImage"
              :alt="resourceName"
              referrerpolicy="no-referrer"
              class="w-full h-full object-contain"
            />
          </div>

          <div class="flex items-center justify-between gap-2">
            <span class="text-xs text-slate-500">
              {{ statusMsg || 'Фотография объекта' }}
            </span>
            <button
              v-if="!isEditing"
              type="button"
              @click="isEditing = true; statusMsg = ''"
              class="px-3.5 py-1.5 rounded-lg text-xs font-semibold bg-slate-100 hover:bg-slate-200 text-slate-800 transition-colors whitespace-nowrap shrink-0"
            >
              Загрузить своё фото
            </button>
          </div>

          <div v-if="isEditing" class="p-4 rounded-lg bg-slate-50 border border-slate-200 space-y-3">
            <div class="text-xs font-semibold text-slate-800">
              Загрузка нового изображения для «{{ resourceName }}»
            </div>

            <div>
              <label class="block text-xs text-slate-600 mb-1">
                Выберите файл с устройства (JPG, PNG, WebP, SVG):
              </label>
              <input
                type="file"
                accept="image/*"
                @change="onFileChange"
                class="block w-full text-xs text-slate-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-sky-600 file:text-white hover:file:bg-sky-700 cursor-pointer"
              />
              <div v-if="selectedFileName" class="text-[11px] text-emerald-700 font-mono mt-1">
                Выбран файл: {{ selectedFileName }}
              </div>
            </div>

            <div v-if="errorMsg" class="text-xs text-rose-600">
              {{ errorMsg }}
            </div>

            <div class="flex items-center justify-end gap-2 pt-1">
              <button
                type="button"
                @click="cancelEdit"
                class="px-3 py-1.5 rounded-lg text-xs font-medium text-slate-600 hover:bg-slate-200 transition-colors"
              >
                Отмена
              </button>
              <button
                type="button"
                :disabled="isSaving"
                @click="saveImage"
                class="px-4 py-1.5 rounded-lg text-xs font-semibold bg-emerald-600 hover:bg-emerald-700 text-white transition-colors whitespace-nowrap shrink-0"
              >
                {{ isSaving ? 'Сохранение...' : 'Сохранить фото' }}
              </button>
            </div>
          </div>
        </div>
      `
    });

    app.mount(mountEl);
  }

  function initNewResourceImageWidget() {
    const mountEl = document.getElementById("vue-new-resource-image");
    if (!mountEl || !window.Vue) return;

    const { createApp, ref } = window.Vue;

    const app = createApp({
      setup() {
        const rawSource = ref("");
        const imageData = ref("");
        const fileName = ref("");

        function handleFile(event) {
          const file = event.target.files && event.target.files[0];
          if (!file) return;
          fileName.value = file.name;

          const reader = new FileReader();
          reader.onload = (e) => {
            rawSource.value = e.target.result;
            imageData.value = e.target.result;
          };
          reader.readAsDataURL(file);
        }

        function clearImage() {
          rawSource.value = "";
          imageData.value = "";
          fileName.value = "";
        }

        return {
          rawSource,
          imageData,
          fileName,
          handleFile,
          clearImage
        };
      },
      template: `
        <div class="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <label class="block text-xs font-semibold text-slate-800">
                Фотография ресурса *
              </label>
              <p class="text-xs text-slate-500 mt-0.5">
                Загрузите фото со своего компьютера
              </p>
            </div>
            <button
              v-if="imageData || rawSource"
              type="button"
              @click="clearImage"
              class="text-xs text-rose-600 hover:underline self-start sm:self-auto"
            >
              Сбросить фото
            </button>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 items-center">
            <div class="space-y-3">
              <div>
                <label class="block text-xs font-medium text-slate-700 mb-1">Загрузить файл с компьютера:</label>
                <input
                  type="file"
                  name="resource[image_file]"
                  accept="image/*"
                  @change="handleFile"
                  class="block w-full text-xs text-slate-600 file:mr-3 file:py-2 file:px-3.5 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-sky-600 file:text-white hover:file:bg-sky-700 cursor-pointer"
                />
                <div v-if="fileName" class="text-xs text-emerald-700 font-mono mt-1">
                  Файл готов к отправке: {{ fileName }}
                </div>
              </div>

              <input type="hidden" name="resource[image_data]" :value="imageData" />
            </div>

            <div class="h-52 rounded-lg overflow-hidden bg-slate-900 border border-slate-200 flex items-center justify-center p-2 relative">
              <img
                v-if="imageData || rawSource"
                :src="imageData || rawSource"
                alt="Предпросмотр ресурса"
                referrerpolicy="no-referrer"
                class="w-full h-full object-contain"
              />
              <div v-else class="text-xs text-slate-400 text-center px-4">
                Предпросмотр фотографии появится здесь после выбора файла
              </div>
            </div>
          </div>
        </div>
      `
    });

    app.mount(mountEl);
  }

  function initBookingCalendarWidget() {
    const mountEl = document.getElementById("vue-booking-widget");
    if (!mountEl || !window.Vue) return;

    const { createApp, ref, computed, onMounted } = window.Vue;

    const resourceId = mountEl.dataset.resourceId;
    const resourceName = mountEl.dataset.resourceName || "Ресурс";
    const hourlyRate = parseInt(mountEl.dataset.hourlyRate || "1500", 10);
    const initialDate = mountEl.dataset.initialDate || new Date().toISOString().split("T")[0];
    const defaultUserName = mountEl.dataset.userName || "";
    const defaultUserEmail = mountEl.dataset.userEmail || "";
    const defaultUserPhone = mountEl.dataset.userPhone || "";

    const app = createApp({
      setup() {
        const selectedDate = ref(initialDate);
        const slots = ref([]);
        const isLoadingSlots = ref(false);
        const startHour = ref(null);
        const endHour = ref(null);
        const overlapWarning = ref("");
        const serverError = ref("");
        const isSubmitting = ref(false);
        const showCheckoutForm = ref(false);

        const availableFromTime = ref(mountEl.dataset.availableFromTime || "09:00");
        const availableToTime = ref(mountEl.dataset.availableToTime || "21:00");
        const availableFromDate = ref(mountEl.dataset.availableFromDate || "");
        const availableToDate = ref(mountEl.dataset.availableToDate || "");
        const isOwner = ref(mountEl.dataset.isOwner === "true");

        const contactName = ref(defaultUserName);
        const contactEmail = ref(defaultUserEmail);
        const contactPhone = ref(defaultUserPhone);
        const purpose = ref("");

        const upcomingDays = computed(() => {
          const result = [];
          const base = new Date();
          for (let i = 0; i < 10; i++) {
            const d = new Date(base);
            d.setDate(base.getDate() + i);
            const iso = d.toISOString().split("T")[0];
            const weekday = d.toLocaleDateString("ru-RU", { weekday: "short" });
            const dayNumber = d.getDate();
            const monthShort = d.toLocaleDateString("ru-RU", { month: "short" });
            result.push({ iso, weekday, dayNumber, monthShort, isToday: i === 0 });
          }
          return result;
        });

        async function fetchAvailability(dateStr) {
          isLoadingSlots.value = true;
          overlapWarning.value = "";
          serverError.value = "";
          try {
            const response = await fetch(
              `/api/v1/resources/${encodeURIComponent(resourceId)}/availability?date=${encodeURIComponent(dateStr)}`,
              { headers: { Accept: "application/json" } }
            );
            if (!response.ok) throw new Error("Не удалось загрузить расписание слотов");
            const data = await response.json();
            slots.value = data.slots || [];
            if (data.available_from_time) availableFromTime.value = data.available_from_time;
            if (data.available_to_time) availableToTime.value = data.available_to_time;
            if (data.available_from_date !== undefined) availableFromDate.value = data.available_from_date || "";
            if (data.available_to_date !== undefined) availableToDate.value = data.available_to_date || "";
          } catch (err) {
            serverError.value = err.message || "Ошибка загрузки расписания";
          } finally {
            isLoadingSlots.value = false;
          }
        }

        function selectDate(dateStr) {
          selectedDate.value = dateStr;
          startHour.value = null;
          endHour.value = null;
          showCheckoutForm.value = false;
          fetchAvailability(dateStr);
        }

        function handleSlotClick(slot) {
          if (!slot.available) return;
          overlapWarning.value = "";
          serverError.value = "";

          const clickedHour = slot.hour;

          if (startHour.value === null || (startHour.value !== null && endHour.value !== null && endHour.value > startHour.value + 1)) {
            startHour.value = clickedHour;
            endHour.value = clickedHour + 1;
            return;
          }

          if (startHour.value === clickedHour && endHour.value === clickedHour + 1) {
            startHour.value = null;
            endHour.value = null;
            showCheckoutForm.value = false;
            return;
          }

          if (clickedHour > startHour.value) {
            const proposedEnd = clickedHour + 1;
            const hasConflictInside = slots.value.some(
              (s) => s.hour >= startHour.value && s.hour < proposedEnd && !s.available
            );

            if (hasConflictInside) {
              overlapWarning.value =
                "Выбранный диапазон пересекается с уже занятым временем. Выбран одиночный слот.";
              startHour.value = clickedHour;
              endHour.value = clickedHour + 1;
              return;
            }

            endHour.value = proposedEnd;
          } else {
            startHour.value = clickedHour;
            endHour.value = clickedHour + 1;
          }
        }

        function isSlotSelected(hour) {
          if (startHour.value === null || endHour.value === null) return false;
          return hour >= startHour.value && hour < endHour.value;
        }

        const durationHours = computed(() => {
          if (startHour.value === null || endHour.value === null) return 0;
          return Math.max(0, endHour.value - startHour.value);
        });

        const totalPrice = computed(() => {
          return durationHours.value * hourlyRate;
        });

        const formattedStartTime = computed(() => {
          if (startHour.value === null) return "";
          return String(startHour.value).padStart(2, "0") + ":00";
        });

        const formattedEndTime = computed(() => {
          if (endHour.value === null) return "";
          return String(endHour.value).padStart(2, "0") + ":00";
        });

        function formatRub(amount) {
          return new Intl.NumberFormat("ru-RU").format(amount) + " ₽";
        }

        async function openCheckout() {
          if (isOwner.value) {
            serverError.value = "Вы являетесь автором этого объявления. Бронирование собственного ресурса недоступно.";
            return;
          }
          if (durationHours.value <= 0) return;
          overlapWarning.value = "";
          serverError.value = "";

          try {
            const res = await fetch("/api/v1/availabilities/check", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Accept: "application/json",
                "X-CSRF-Token": getCsrfToken()
              },
              body: JSON.stringify({
                resource_id: resourceId,
                booking_date: selectedDate.value,
                start_time: formattedStartTime.value,
                end_time: formattedEndTime.value
              })
            });
            const checkData = await res.json();
            if (!checkData.available) {
              overlapWarning.value =
                "Внимание: этот интервал только что был занят другим пользователем. Сетка слотов обновлена.";
              await fetchAvailability(selectedDate.value);
              return;
            }
            showCheckoutForm.value = true;
          } catch (e) {
            showCheckoutForm.value = true;
          }
        }

        async function submitBooking() {
          if (isOwner.value) {
            serverError.value = "Вы являетесь автором этого объявления. Бронирование собственного ресурса недоступно.";
            return;
          }
          if (!contactName.value.trim() || !contactEmail.value.trim()) {
            serverError.value = "Укажите имя и электронную почту для отправки подтверждения.";
            return;
          }

          isSubmitting.value = true;
          serverError.value = "";

          try {
            const response = await fetch("/bookings", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Accept: "application/json",
                "X-CSRF-Token": getCsrfToken()
              },
              body: JSON.stringify({
                booking: {
                  resource_id: resourceId,
                  booking_date: selectedDate.value,
                  start_time: formattedStartTime.value,
                  end_time: formattedEndTime.value,
                  purpose: purpose.value.trim(),
                  contact_name: contactName.value.trim(),
                  contact_email: contactEmail.value.trim(),
                  contact_phone: contactPhone.value.trim()
                }
              })
            });

            const result = await response.json();
            if (!response.ok) {
              const msg =
                (result.errors && result.errors.join(", ")) ||
                "Не удалось сохранить бронирование. Проверьте выбранное время.";
              serverError.value = msg;
              await fetchAvailability(selectedDate.value);
              return;
            }

            if (result.redirect_url) {
              window.location.href = result.redirect_url;
            } else if (result.booking && result.booking.id) {
              window.location.href = `/bookings/${result.booking.id}`;
            }
          } catch (err) {
            serverError.value = "Ошибка при отправке заявки на бронирование.";
          } finally {
            isSubmitting.value = false;
          }
        }

        const freeSlotsCount = computed(() => {
          return slots.value.filter((s) => s.available).length;
        });

        onMounted(() => {
          fetchAvailability(selectedDate.value);
        });

        return {
          resourceName,
          hourlyRate,
          isOwner,
          availableFromTime,
          availableToTime,
          availableFromDate,
          availableToDate,
          selectedDate,
          upcomingDays,
          slots,
          isLoadingSlots,
          startHour,
          endHour,
          durationHours,
          totalPrice,
          formattedStartTime,
          formattedEndTime,
          overlapWarning,
          serverError,
          showCheckoutForm,
          isSubmitting,
          contactName,
          contactEmail,
          contactPhone,
          purpose,
          freeSlotsCount,
          selectDate,
          handleSlotClick,
          isSlotSelected,
          formatRub,
          openCheckout,
          submitBooking
        };
      },
      template: `
        <div class="bg-white border border-slate-200 rounded-xl p-6">
          <div class="flex flex-wrap items-baseline justify-between gap-4 pb-5 border-b border-slate-200">
            <div>
              <h2 class="text-xl font-bold text-slate-900 font-display">
                Выбор даты и времени бронирования
              </h2>
              <p class="text-sm text-slate-600 mt-1">
                Выберите дату и отметьте один или несколько свободных часовых интервалов
              </p>
            </div>
            <div class="text-sm text-slate-600 font-mono tabular-nums">
              Свободно слотов: <strong class="text-slate-900">{{ freeSlotsCount }} из {{ slots.length }}</strong>
            </div>
          </div>

          <!-- Шаг 1: Выбор даты -->
          <div class="mt-6">
            <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
              <label class="text-sm font-semibold text-slate-900">
                1. Дата бронирования
              </label>
              <input
                type="date"
                :value="selectedDate"
                @change="selectDate($event.target.value)"
                class="px-3 py-1.5 text-sm font-mono tabular-nums border border-slate-300 rounded-lg text-slate-900 focus:outline-none focus:border-sky-600"
              />
            </div>

            <div class="grid grid-cols-5 sm:grid-cols-10 gap-2">
              <button
                v-for="day in upcomingDays"
                :key="day.iso"
                type="button"
                @click="selectDate(day.iso)"
                :class="[
                  'py-2.5 px-2 rounded-lg border text-center transition-colors',
                  selectedDate === day.iso
                    ? 'bg-sky-600 border-sky-600 text-white font-semibold'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                ]"
              >
                <div :class="['text-xs', selectedDate === day.iso ? 'text-sky-100' : 'text-slate-500']">
                  {{ day.weekday }}
                </div>
                <div class="text-base font-bold font-mono tabular-nums my-0.5">
                  {{ day.dayNumber }}
                </div>
                <div :class="['text-[11px]', selectedDate === day.iso ? 'text-sky-100' : 'text-slate-500']">
                  {{ day.monthShort }}
                </div>
              </button>
            </div>
          </div>

          <!-- Шаг 2: Почасовая сетка слотов -->
          <div class="mt-6">
            <div class="flex flex-wrap items-center justify-between gap-2 mb-3">
              <label class="text-sm font-semibold text-slate-900">
                2. Часовые интервалы ({{ availableFromTime }} – {{ availableToTime }})
              </label>
              <div class="text-xs text-slate-600">
                Свободно · Выбрано · Занято
              </div>
            </div>

            <div v-if="isLoadingSlots" class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2.5 py-2">
              <div v-for="n in 12" :key="n" class="h-16 rounded-lg bg-slate-100 animate-pulse border border-slate-200"></div>
            </div>

            <div v-else-if="slots.length === 0" class="p-8 text-center text-sm text-slate-500 bg-slate-50 border border-slate-200 rounded-xl">
              На выбранную дату слоты для бронирования недоступны (вне графика доступности ресурса).
            </div>

            <div v-else class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2.5">
              <button
                v-for="slot in slots"
                :key="slot.hour"
                type="button"
                :disabled="!slot.available"
                @click="handleSlotClick(slot)"
                :class="[
                  'py-3 px-2.5 rounded-lg border text-left transition-colors flex flex-col justify-between',
                  !slot.available
                    ? 'bg-slate-100 border-slate-200 text-slate-400 cursor-not-allowed'
                    : isSlotSelected(slot.hour)
                    ? 'bg-sky-600 border-sky-600 text-white'
                    : 'bg-white border-slate-200 text-slate-900 hover:border-sky-600 hover:bg-sky-50/40'
                ]"
              >
                <span class="font-mono text-sm font-semibold tabular-nums">
                  {{ slot.time_label }}–{{ slot.end_label }}
                </span>
                <span :class="[
                  'text-xs mt-1 truncate',
                  !slot.available
                    ? 'text-rose-600 font-medium'
                    : isSlotSelected(slot.hour)
                    ? 'text-sky-100'
                    : 'text-emerald-700'
                ]">
                  {{ !slot.available ? 'Занято' : isSlotSelected(slot.hour) ? 'Выбрано' : 'Свободно' }}
                </span>
              </button>
            </div>

            <div v-if="overlapWarning" class="mt-4 p-3.5 rounded-lg bg-amber-50 border border-amber-200 text-sm text-amber-900">
              {{ overlapWarning }}
            </div>

            <div v-if="serverError" class="mt-4 p-3.5 rounded-lg bg-rose-50 border border-rose-200 text-sm text-rose-900">
              {{ serverError }}
            </div>
          </div>

          <!-- Итоговая панель расчета стоимости -->
          <div class="mt-6 pt-5 border-t border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <div class="text-xs text-slate-500">Выбранный период и расчет стоимости:</div>
              <div v-if="durationHours > 0" class="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <span class="font-mono text-base font-bold text-slate-900 tabular-nums">
                  {{ selectedDate }} · {{ formattedStartTime }}–{{ formattedEndTime }} ({{ durationHours }} ч.)
                </span>
                <span class="text-sm text-slate-600 font-mono tabular-nums">
                  {{ formatRub(hourlyRate) }} × {{ durationHours }} ч. =
                  <strong class="text-lg font-bold text-sky-700">{{ formatRub(totalPrice) }}</strong>
                </span>
              </div>
              <div v-else class="text-sm text-slate-500 mt-1">
                Кликните на начальный и конечный свободный слот в таблице выше
              </div>
            </div>

            <div v-if="isOwner" class="px-4 py-2.5 rounded-lg text-xs font-semibold bg-amber-100 text-amber-800 border border-amber-200">
              Нельзя забронировать свое объявление
            </div>
            <button
              v-else-if="!showCheckoutForm"
              type="button"
              :disabled="durationHours <= 0"
              @click="openCheckout"
              :class="[
                'px-5 py-2.5 rounded-lg text-sm font-semibold whitespace-nowrap shrink-0 transition-colors',
                durationHours > 0
                  ? 'bg-sky-600 text-white hover:bg-sky-700 cursor-pointer'
                  : 'bg-slate-200 text-slate-500 cursor-not-allowed'
              ]"
            >
              Перейти к оформлению
            </button>
          </div>

          <!-- Шаг 3: Форма оформления бронирования -->
          <form
            v-if="showCheckoutForm && durationHours > 0"
            @submit.prevent="submitBooking"
            class="mt-6 pt-6 border-t border-slate-200 space-y-4"
          >
            <h3 class="text-base font-bold text-slate-900 font-display">
              3. Контактные данные для бронирования
            </h3>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs font-semibold text-slate-700 mb-1">
                  Имя и фамилия *
                </label>
                <input
                  type="text"
                  v-model="contactName"
                  required
                  placeholder="Алексей Пономарев"
                  class="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg text-slate-900 focus:outline-none focus:border-sky-600"
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 mb-1">
                  Электронная почта *
                </label>
                <input
                  type="email"
                  v-model="contactEmail"
                  required
                  placeholder="user@example.ru"
                  class="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg text-slate-900 focus:outline-none focus:border-sky-600"
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 mb-1">
                  Контактный телефон
                </label>
                <input
                  type="tel"
                  v-model="contactPhone"
                  placeholder="+7 (999) 123-45-67"
                  class="w-full px-3 py-2 text-sm font-mono tabular-nums border border-slate-300 rounded-lg text-slate-900 focus:outline-none focus:border-sky-600"
                />
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-slate-700 mb-1">
                Цель бронирования / комментарий
              </label>
              <input
                type="text"
                v-model="purpose"
                placeholder="Например: Командная встреча или запись интервью"
                class="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg text-slate-900 focus:outline-none focus:border-sky-600"
              />
            </div>

            <div class="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                @click="showCheckoutForm = false"
                class="px-4 py-2 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-100 transition-colors"
              >
                Назад к выбору времени
              </button>
              <button
                type="submit"
                :disabled="isSubmitting"
                class="px-5 py-2.5 rounded-lg text-sm font-semibold bg-emerald-600 hover:bg-emerald-700 text-white transition-colors whitespace-nowrap shrink-0"
              >
                {{ isSubmitting ? 'Оформление...' : 'Подтвердить бронирование за ' + formatRub(totalPrice) }}
              </button>
            </div>
          </form>
        </div>
      `
    });

    app.mount(mountEl);
  }

  function bootAllVueWidgets() {
    initResourceImageUploader();
    initNewResourceImageWidget();
    initBookingCalendarWidget();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootAllVueWidgets);
  } else {
    bootAllVueWidgets();
  }
})();
