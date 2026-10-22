require "application_system_test_case"

class ToastsSystemTest < ApplicationSystemTestCase
  test "toast text and action labels remain text and dismiss is keyboard accessible" do
    visit root_url
    page.execute_script <<~JS
      window.toast('<b data-injected="message">Message</b>', {
        description: '<img src="missing" onerror="window.toastInjection = true">',
        action: { label: '<b data-injected="action">Action</b>', onClick: () => {} },
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

  test "toast limit retains the newest messages and cleans up before a Turbo navigation" do
    visit root_url
    page.execute_script <<~JS
      const controller = Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast');
      controller.autoDismissDurationValue = 60000;
      for (let i = 1; i <= 5; i++) window.toast(`Notification ${i}`);
    JS

    assert_selector '.toast-item[data-mounted="true"][data-removed="false"]', count: 3
    [ 3, 4, 5 ].each { |number| assert_selector '.toast-item[data-removed="false"]', text: "Notification #{number}", visible: :all }
    assert_no_selector '.toast-item[data-removed="false"]', text: "Notification 1", visible: :all
    assert_no_selector '.toast-item[data-removed="false"]', text: "Notification 2", visible: :all

    page.execute_script("window.toast('Pending animation'); Turbo.visit('#{ride_posts_path}')")
    assert_current_path ride_posts_path
    assert_no_selector ".toast-item"
    page.execute_script("window.toast('Ready after navigation')")
    assert_selector '.toast-item[data-mounted="true"]', text: "Ready after navigation"
  end
end
