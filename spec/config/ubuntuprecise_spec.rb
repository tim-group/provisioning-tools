describe Provision do
  it 'after building a test vm I am able to login' do
    Provision.vm(:hostname=>RANDOMX, :template=>ubuntuprecise)
  end

  it 'after building a test vm I can verify the host is the one I specified' do
  end
end