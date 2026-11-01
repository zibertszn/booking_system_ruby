# frozen_string_literal: true

puts "Наполнение базы данных тестовыми данными (db:seed)..."

alex = User.find_or_create_by!(email: "AlePon1999@gmail.com") do |u|
  u.name = "Алексей Пономарев"
  u.phone = "+7 (999) 123-45-67"
  u.password = "password123"
  u.password_confirmation = "password123"
end

maria = User.find_or_create_by!(email: "maria.smirnova@example.ru") do |u|
  u.name = "Мария Смирнова"
  u.phone = "+7 (916) 456-78-90"
  u.password = "password123"
  u.password_confirmation = "password123"
end

resources_data = [
  {
    slug: "res_alpha",
    name: "Переговорная «Альфа»",
    category: "rooms",
    category_name: "Помещение",
    description: "Светлая переговорная со звукоизоляцией, 4K-дисплеем 65 дюймов и системой видеоконференцсвязи Logitech MeetUp. Оптимальна для командных встреч и планерки.",
    location: "Корпус А, 3 этаж, зал 302",
    capacity: 10,
    hourly_rate: 1500,
    amenities: ["4K Дисплей 65\"", "Logitech MeetUp", "Маркерная стена", "Wi-Fi 6E"],
    image_url: "/images/room_alpha.svg"
  },
  {
    slug: "res_orion",
    name: "Конференц-зал «Орион»",
    category: "rooms",
    category_name: "Помещение",
    description: "Просторный зал-амфитеатр для проведения семинаров, защит проектов и презентаций. Оснащен лазерным проектором, трибуной и двумя радиомикрофонами.",
    location: "Главный корпус, 1 этаж, холл B",
    capacity: 35,
    hourly_rate: 3500,
    amenities: ["Лазерный проектор", "2 Радиомикрофона", "Акустика Bose", "Климат-контроль"],
    image_url: "/images/room_orion.svg"
  },
  {
    slug: "res_silence",
    name: "Акустическая капсула «Тишина»",
    category: "rooms",
    category_name: "Помещение",
    description: "Звукоизолированная кабина для индивидуальных созвонов и встреч 1-на-1 с автономной бесшумной вентиляцией и направленным освещением.",
    location: "Коворкинг-зона, 2 этаж",
    capacity: 2,
    hourly_rate: 800,
    amenities: ["Шумоизоляция 38 дБ", "Вентиляция", "Розетки 220V + USB-C", "Стол с регулировкой"],
    image_url: "/images/room_silence.svg"
  },
  {
    slug: "res_podcast",
    name: "Подкаст-комплект Shure & RodeCaster",
    category: "equipment",
    category_name: "Оборудование",
    description: "Профессиональный комплект для записи подкастов и эфиров: пульт RodeCaster Pro II, два динамических микрофона Shure SM7B на пантографах и студийные наушники.",
    location: "Медиа-лаборатория, каб. 114",
    capacity: nil,
    hourly_rate: 1200,
    amenities: ["2x Shure SM7B", "RodeCaster Pro II", "Преампы Cloudlifter", "Карта microSD 128 ГБ"],
    image_url: "/images/eq_podcast.svg"
  },
  {
    slug: "res_camera",
    name: "Комплект съемки Sony A7 IV + 24-70 GM",
    category: "equipment",
    category_name: "Оборудование",
    description: "Полнокадровая гибридная камера Sony Alpha 7 IV со светосильным объективом 24-70mm f/2.8 G-Master II и трехосевым стабилизатором DJI RS3 Pro.",
    location: "Цех видеооборудования, каб. 110",
    capacity: nil,
    hourly_rate: 2000,
    amenities: ["Sony A7 IV Body", "Объектив 24-70 f/2.8 GM", "Стабилизатор DJI RS3", "3 аккумулятора NP-FZ100"],
    image_url: "/images/eq_camera.svg"
  },
  {
    slug: "res_sound_eng",
    name: "Консультация звукорежиссера",
    category: "specialists",
    category_name: "Специалисты",
    description: "Индивидуальная сессия со штатным аудиоинженером: постановка звука, запись дикторского голоса, чистка шумов и мастеринг аудиодорожек.",
    location: "Студия звукозаписи Б, 1 этаж",
    capacity: nil,
    hourly_rate: 2500,
    amenities: ["Запись и сведение", "Чистка аудио iZotope RX", "Отстройка тракта", "Мастеринг под площадки"],
    image_url: "/images/spec_sound.svg"
  }
]

resources_data.each_with_index do |attrs, idx|
  Resource.find_or_create_by!(slug: attrs[:slug]) do |r|
    r.assign_attributes(attrs)
    r.user = idx.even? ? alex : maria
  end
end

alpha = Resource.find_by!(slug: "res_alpha")
podcast = Resource.find_by!(slug: "res_podcast")
today = Date.current

if Booking.count.zero?
  Booking.create!(
    user: maria,
    resource: alpha,
    booking_date: today,
    start_time: "10:00",
    end_time: "12:00",
    purpose: "Планирование квартального спринта команды",
    contact_name: maria.name,
    contact_email: maria.email,
    contact_phone: maria.phone
  )

  Booking.create!(
    user: maria,
    resource: alpha,
    booking_date: today,
    start_time: "14:00",
    end_time: "16:00",
    purpose: "Ревью дизайн-системы и планирование спринта",
    contact_name: maria.name,
    contact_email: maria.email,
    contact_phone: maria.phone
  )

  Booking.create!(
    user: alex,
    resource: podcast,
    booking_date: today + 1.day,
    start_time: "15:00",
    end_time: "17:00",
    purpose: "Запись интервью и подкаста в студии",
    contact_name: alex.name,
    contact_email: alex.email,
    contact_phone: alex.phone
  )
end

puts "Готово: создано пользователей: #{User.count}, ресурсов: #{Resource.count}, бронирований: #{Booking.count}."
