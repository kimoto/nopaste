describe 'entry' do
  it '本文の長さが65535より多いとエラーになる' do
    expect {
      Entry.create(:body => 'a' * 65536)
    }.to raise_error(DataMapper::SaveFailureError)
    data = 'a' * 65535
    entry = Entry.create(:body => data)
    expect(entry.body).to eq(data)
  end
end
