# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home with active carpool routes" do
    get root_url
    assert_response :success
    assert_select "h2", text: /Active Carpool Routes/
  end

  test "should get privacy with all statutory sections and disclosures" do
    get privacy_url
    assert_response :success

    assert_select "h1", text: "Privacy Policy"
    assert_select "p", text: /Effective Date: October 3, 2026/

    # Verify key section headings
    assert_select "h2", text: /1\. Introduction & Controller Identity/
    assert_select "h2", text: /2\. Information We Collect/
    assert_select "h2", text: /3\. Legal Basis & Purpose of Processing/
    assert_select "h2", text: /4\. Information Sharing & Public Visibility/
    assert_select "h2", text: /5\. In-App Chat Privacy & Moderation Protocol/
    assert_select "h2", text: /6\. Cookies & Technical Session Storage/
    assert_select "h2", text: /7\. Data Retention & Account Deletion Policy/
    assert_select "h2", text: /8\. External Service Providers/
    assert_select "h2", text: /9\. Data Subject Rights/
    assert_select "h2", text: /10\. Information Security Measures/
    assert_select "h2", text: /11\. Changes to this Privacy Policy/

    # Disclosures
    assert_select "li", text: /Public Visitors.*first name, last name, and profile avatar/
    assert_select "a[href='mailto:privacy@pasabaya.app']"
    assert_select "li", text: /Umami Cloud/
    assert_select "li", text: /Mailtrap/
    assert_select "li", text: /six monthly, and two yearly snapshots/
    assert_select "li", text: /separate persistent deletion registry/
    assert_select "li", text: /up to 30 days/, count: 0
    assert_select "li", text: /At the history deadline.*inaccessible.*scheduled for permanent deletion/
    assert_select "li", text: /Queue delays.*physical deletion/
    assert_select "li", text: /canceled while messaging is open.*24 hours after cancellation/
  end

  test "should get terms with warning banner and protective clauses" do
    get terms_url
    assert_response :success

    assert_select "h1", text: "Terms of Service"
    assert_select "p", text: /Effective Date: October 3, 2026/

    # Warning banner
    assert_select "h2", text: /CRITICAL NOTICE: PLEASE READ CAREFULLY/
    assert_select "p", text: /free, non-commercial digital bulletin board/

    # Key protective sections
    assert_select "h2", text: /1\. Acceptance of Terms/
    assert_select "h2", text: /2\. Eligibility & User Representations/
    assert_select "h2", text: /3\. Nature of the Platform/
    assert_select "h2", text: /4\. Non-Commercial Expense Sharing & Prohibition of Commercial Transport/
    assert_select "h2", text: /5\. Absolute Zero Financial Intermediation/
    assert_select "h2", text: /6\. Booking, Driver Discretion & Ladies Only Preference/
    assert_select "h2", text: /7\. In-App Coordination Chat & Acceptable Use/
    assert_select "h2", text: /8\. Reliability, No-Show Incidents & Account Freezes/
    assert_select "h2", text: /9\. Assumption of Risk & Safety Due Diligence/
    assert_select "h2", text: /10\. Disclaimer of Warranties/
    assert_select "h2", text: /11\. Limitation of Liability/
    assert_select "h2", text: /12\. Indemnification/
    assert_select "h2", text: /13\. Administration Rights, Suspension & Termination/
    assert_select "h2", text: /14\. Modifications to Terms/
    assert_select "h2", text: /15\. Governing Law & Dispute Resolution/

    assert_select "li", text: /rolling 60-day window/
    assert_select "li", text: /7-day freeze/
    assert_select "a[href='mailto:legal@pasabaya.app']"
  end
end
