describe 'entry' do
  it '本文の長さが65535より多いとエラーになる' do
    expect {
      Entry.create(:body => 'a' * 65536)
    }.to raise_error(DataMapper::SaveFailureError)
    data = 'a' * 65535
    entry = Entry.create(:body => data)
    expect(entry.body).to eq(data)
  end

  it '指定しようと思えば任意のdigestを指定できる' do
    entry = Entry.create(:digest => 'aAaA', :body => 'hell world!')
    expect(entry.digest).to eq('aAaA')
  end

  it 'digestの長さは64文字以下である' do
    expect{
      Entry.create(:digest => 'A' * 65, :body => 'aaa')
    }.to raise_error(DataMapper::SaveFailureError)
    entry = Entry.create(:digest => 'A' * 64, :body => 'aaa')
    expect(entry.digest).to eq('A' * 64)
  end
end
