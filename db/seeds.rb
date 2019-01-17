include ActionDispatch::TestProcess
muppet_upload = fixture_file_upload(
  File.join('spec/fixtures/files/muppets.mp3'), 'audio/mpeg'
)
blue_de_bresse_upload = fixture_file_upload(
  File.join('spec/fixtures/images/blue_de_bresse.jpg'), 'image/jpg'
)
cheshire_cheese_upload = fixture_file_upload(
  File.join('spec/fixtures/images/cheshire_cheese.jpg'), 'image/jpg'
)
marie_upload = fixture_file_upload(
  File.join('spec/fixtures/images/marie.jpg'), 'image/jpg'
)

def put_user_credentials(username, password)
  puts "You can now sign in with: #{username} - #{password}"
end

# Create admin account.
admin_password = 'testing123'
admin = User.create(
  login: 'admin',
  email: 'admin@example.com',
  password: admin_password,
  password_confirmation: admin_password,
  admin: true
)
put_user_credentials(admin.login, admin_password)

# Create moderator account.
moderator_password = 'mod123'
moderator = User.create(
  login: 'moderator',
  email: 'moderator@example.com',
  password: moderator_password,
  password_confirmation: moderator_password,
  moderator: true
)
put_user_credentials(moderator.login, moderator_password)

# Create regular musician account.
musician_password = 'music123'
musician = User.create!(
  login: 'musician',
  email: 'musician@example.com',
  password: musician_password,
  password_confirmation: musician_password,
  greenfield_enabled: true
)
put_user_credentials(musician.login, musician_password)

# Create a regular musician account with playlists and tracks.
marie_password = 'testing123'
marie = User.create!(
  login: 'marieh',
  email: 'marie.harel@example.com',
  password: marie_password,
  password_confirmation: marie_password,
  greenfield_enabled: true
)
put_user_credentials(marie.login, marie_password)

# Add an avatar for Marie
unless marie.pic
  marie.create_pic(pic: marie_upload)
end

# Create a few assets for Marie.
instrument_of_accession = marie.assets.create(
  mp3: muppet_upload,
  title: 'Commonly Blue-grey',
  description: 'The color of camembert rind was a matter of chance, most commonly blue-grey, with brown spots.',
  waveform: Greenfield::Waveform.extract(muppet_upload.path)
)
tropical_semi_evergreen = marie.assets.create(
  mp3: muppet_upload,
  title: 'Aqueous Suspension',
  description: 'The surface of each cheese is then sprayed with an aqueous suspension of the mold Penicillium camemberti.',
  waveform: Greenfield::Waveform.extract(muppet_upload.path)
)

# Add the assets to a playlist for Marie.
before_fungi = marie.playlists.build(
  title: 'Before fungi were understood',
  year: Date.today.year - 1
)
before_fungi.description = <<~DESC
  The variety named Camembert de Normandie was granted a protected designation of origin in 1992
  after the original AOC in 1983.
DESC
before_fungi.save!
before_fungi.tracks.create!(user: marie, asset: instrument_of_accession)
before_fungi.tracks.create!(user: marie, asset: tropical_semi_evergreen)
before_fungi.update(private: false)

# Create a few more assets for Marie.
creamy_interior = marie.assets.create(
  mp3: muppet_upload,
  title: 'Creamy Interior',
  description: 'Contains patches of blue mold',
  waveform: Greenfield::Waveform.extract(muppet_upload.path)
)
cylindrical_rounds = marie.assets.create(
  mp3: muppet_upload,
  title: 'Cylindrical Rounds',
  description: 'It is shaped into cylindrical rounds weighing from 125 to 500 grams.',
  waveform: Greenfield::Waveform.extract(muppet_upload.path)
)

# Add the assets to a playlist for Marie.
edible_coating = marie.playlists.build(
  title: 'Edible Coating',
  year: Date.today.year
)
edible_coating.description = <<~DESC
  Edible coating which is characteristically white in color and has an aroma of mushrooms.
DESC
edible_coating.save!
edible_coating.tracks.create!(user: marie, asset: creamy_interior)
edible_coating.tracks.create!(user: marie, asset: cylindrical_rounds)
edible_coating.update(private: false)

# Add a cover for Edible Coating.
unless edible_coating.pic
  edible_coating.create_pic(pic: blue_de_bresse_upload)
end

# Create another regular musician account with playlists and tracks.
lucy_password = 'testing123'
lucy = User.create!(
  login: 'lucy',
  email: 'lucy.appleby@example.com',
  display_name: 'Lucy 🍎',
  password: lucy_password,
  password_confirmation: lucy_password,
  greenfield_enabled: true
)
put_user_credentials(lucy.login, lucy_password)

# Create a few more assets for Lucy.
keep_tradition_alive = lucy.assets.create(
  mp3: muppet_upload,
  title: 'Keep Tradition Alive',
  description: 'Cloth-bound Cheshire cheeses from their own unpasteurised milk',
  waveform: Greenfield::Waveform.extract(muppet_upload.path)
)
much_like_cheddar = lucy.assets.create(
  mp3: muppet_upload,
  title: 'Much Like Cheddar',
  description: 'Cheshire cheese is made much like cheddar (now the name of a process, rather than a geographical designation) or Lancashire',
  waveform: Greenfield::Waveform.extract(muppet_upload.path)
)

# Add the assets to a playlist for Lucy.
mrs_applebys_cheshire = lucy.playlists.build(
  title: "Mrs Appleby's Cheshire",
  year: Date.today.year - 2
)
mrs_applebys_cheshire.description = <<~DESC
  Edible coating which is characteristically white in color and has an aroma of mushrooms.
DESC
mrs_applebys_cheshire.save!
mrs_applebys_cheshire.tracks.create!(user: lucy, asset: keep_tradition_alive)
mrs_applebys_cheshire.tracks.create!(user: lucy, asset: much_like_cheddar)
mrs_applebys_cheshire.update(private: false)

# Add a cover for Mrs Appleby's Cheshire.
unless mrs_applebys_cheshire.pic
  mrs_applebys_cheshire.create_pic(pic: cheshire_cheese_upload)
end

# Some random listens.
10.times do
  Asset.find_each do |asset|
    User.find_each do |user|
      if rand(4) == 1
        asset.listens.create(
          listener: user,
          track_owner: asset.user,
          user_agent: 'seeds/v1.0',
          ip: '127.0.0.1'
        )
      end
    end
  end
end
