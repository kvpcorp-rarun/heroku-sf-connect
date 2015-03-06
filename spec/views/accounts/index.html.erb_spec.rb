require 'rails_helper'

RSpec.describe "accounts/index", type: :view do
  before(:each) do
    assign(:accounts, [
      Account.create!(
        :first_name => "First Name",
        :last_name => "Last Name",
        :email => "Email"
      ),
      Account.create!(
        :first_name => "First Name",
        :last_name => "Last Name",
        :email => "Email"
      )
    ])
  end

  it "renders a list of accounts" do
    render
    assert_select "tr>td", :text => "First Name".to_s, :count => 2
    assert_select "tr>td", :text => "Last Name".to_s, :count => 2
    assert_select "tr>td", :text => "Email".to_s, :count => 2
  end
end
