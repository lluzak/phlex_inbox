require "test_helper"

class ContactTest < ActiveSupport::TestCase
  test "initials returns first letters of name" do
    contact = Contact.new(name: "John Doe", email: "john@example.com")
    assert_equal "JD", contact.initials
  end

  test "validates presence of name and email" do
    contact = Contact.new
    assert_not contact.valid?
    assert_includes contact.errors[:name], "can't be blank"
    assert_includes contact.errors[:email], "can't be blank"
  end
end
