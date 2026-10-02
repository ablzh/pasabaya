require "application_system_test_case"

class ToastsSystemTest < ApplicationSystemTestCase
  test "toast text and action labels remain text and dismiss is keyboard accessible" do
    visit root_url
    page.execute_script <<~JS
      window.toast('<b data-injected="message">Message</b>', {
        description: '<img src="missing" onerror="window.toastInjection = true">',
        action: { label: '<b data-injected="action">Action</b>', onClick: () => {} },
        secondaryAction: { label: '<b data-injected="secondary">Secondary</b>', onClick: () => {} },
        type: 'info'
      })
    JS

    assert_selector ".toast-item", text: '<b data-injected="message">Message</b>'
    assert_no_selector ".toast-item [data-injected]"
    assert_no_selector ".toast-item img"
    assert_nil page.evaluate_script("window.toastInjection")
    find('button[aria-label="Dismiss notification"]').send_keys(:enter)
    assert_no_selector '.toast-item[data-removed="false"]'
  end
end
