# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  # --- Ассоциации ---
  describe "ассоциации" do
    it { is_expected.to have_many(:bookings).dependent(:destroy) }
    it { is_expected.to have_many(:resources).dependent(:destroy) }
  end

  # --- Devise-модули ---
  describe "devise" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
  end

  # --- Валидации ---
  describe "валидации имени" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }
  end

  # --- Фабрика ---
  describe "фабрика" do
    it "создаёт валидного пользователя" do
      expect(build(:user)).to be_valid
    end

    it "не валидна без имени" do
      expect(build(:user, name: "")).not_to be_valid
    end

    it "не валидна с именем короче 2 символов" do
      expect(build(:user, name: "А")).not_to be_valid
    end

    it "не валидна без email" do
      expect(build(:user, email: "")).not_to be_valid
    end

    it "не валидна с дублирующимся email" do
      create(:user, email: "dup@example.com")
      expect(build(:user, email: "dup@example.com")).not_to be_valid
    end

    it "не валидна без пароля" do
      expect(build(:user, password: "", password_confirmation: "")).not_to be_valid
    end
  end
end
