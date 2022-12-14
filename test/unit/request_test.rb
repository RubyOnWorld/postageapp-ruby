require_relative '../helper'

class RequestTest < MiniTest::Test
  def test_method_uid
    request = PostageApp::Request.new('test_method')

    uid = request.uid

    assert_match(/\A\w{40}\z/, uid)
    assert_equal uid, request.uid
    assert uid != request.uid(true)
  end

  def test_method_url
    request = PostageApp::Request.new('test_method')

    assert_equal 'api.postageapp.com', request.url.host
    assert_equal 443, request.url.port
    assert_equal '/v.1.1/test_method.json', request.url.path
  end

  def test_method_arguments_to_send
    request = PostageApp::Request.new('send_message',
      'headers' => {
        'from' => 'sender@test.test',
        'subject' => 'Test Message'
      },
      'recipients' => 'test@test.test',
      'content' => {
        'text/plain' => 'text content',
        'text/html' => 'html content'
      }
    )

    args = request.arguments_to_send

    assert args['api_key']
    assert !args['api_key'].empty?
    assert_match(/^\w{40}$/, args['uid'])

    payload = args['arguments']

    assert_equal 'sender@test.test', payload['headers']['from']
    assert_equal 'Test Message', payload['headers']['subject']
    assert_equal 'test@test.test', payload['recipients']
    assert_equal 'text content', payload['content']['text/plain']
    assert_equal 'html content', payload['content']['text/html']

    request.arguments = { 'data' => 'content' }

    args = request.arguments_to_send

    assert !args['api_key'].empty?
    assert_match(/^\w{40}$/, args['uid'])
    assert_equal 'content', args['arguments']['data']
  end

  def test_uid_is_enforceable
    request = PostageApp::Request.new('test_method')

    assert_match(/^\w{40}$/, request.arguments_to_send['uid'])

    request.uid = 'my_uid'

    assert_equal 'my_uid', request.arguments_to_send['uid']

    request = PostageApp::Request.new('test_method', 'uid' => 'new_uid', 'data' => 'value')

    assert_equal 'new_uid', request.uid
    assert_equal({ 'data' => 'value' }, request.arguments)
  end

  def test_api_key
    request = PostageApp::Request.new('test_method')

    assert_equal PostageApp.configuration.api_key, request.api_key

    request = PostageApp::Request.new('test_method', {
      'api_key' => 'custom_api_key'
    })

    assert_equal 'custom_api_key', request.api_key
  end

  def test_send
    mock_successful_send

    request = PostageApp::Request.new('send_message',
      'headers' => {
        'from' => 'sender@test.test',
        'subject' => 'Test Message'
      },
      'recipients' => 'test@test.test',
      'content' => {
        'text/plain' => 'text content',
        'text/html' => 'html content'
      }
    )

    response = request.send

    assert_equal 'ok', response.status
    assert_equal 'sha1hashuid23456789012345678901234567890', response.uid
    assert_equal({ 'message' => { 'id' => 999 } }, response.data)
  end

  def test_send_failure
    mock_failed_send

    request = PostageApp::Request.new(
      'send_message',
      'headers' => {
        'from' => 'sender@test.test',
        'subject' => 'Test Message'
      },
      'recipients' => 'test@test.test',
      'content' => {
        'text/plain' => 'text content',
        'text/html' => 'html content'
      }
    )

    response = request.send

    assert_equal 'fail', response.status
    assert_nil response.uid
    assert_nil response.data
  end
end
