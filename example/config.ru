class HelloApp
  def call(env)
    # p env
    [
      200,
      { 'Content-Type' => 'text/html' },
      ['hello world ']
    ]
  end
end

run HelloApp.new

