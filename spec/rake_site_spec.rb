# frozen_string_literal: true

require 'rake'
require 'digest/md5'

describe 'With working org files' do
  before(:all) do
    init_testing_website
    @rake = init_rake_and_install_org
  end

  before(:each) do
    @rake.options.build_all = true
    @rake.tasks.each(&:reenable)
    Rake.verbose(false)
  end

  after(:all) do
    Dir.chdir File.expand_path('../', __dir__)
    FileUtils.rm_r 'spec/data/website_testing', force: true
  end

  describe 'Build process' do
    before(:each) do
      o = Neruda::OrgFile.new('src/index.org', 'title' => 'My website')
      o.write
    end

    after(:each) do
      FileUtils.rm 'public_html/index.html', force: true
    end

    it 'should build something' do
      @rake.invoke_task('site:build')
      expect(File.exist?('public_html/index.html')).to be(true)
    end

    it 'should build something even in verbose mode' do
      Rake.verbose(true)
      @rake.invoke_task('site:build')
      expect(File.exist?('public_html/index.html')).to be(true)
    end

    it 'should build one specific file' do
      o = Neruda::OrgFile.new('src/tutu.org', 'title' => 'Tutu test')
      o.write
      @rake.invoke_task('site:build[src/tutu.org]')
      expect(File.exist?('public_html/index.html')).to be(false)
      expect(File.exist?('public_html/tutu.html')).to be(true)
    end
  end

  describe 'Customize process' do
    before(:each) do
      html_base = <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <title>My website</title>
          </head>
          <body>
            <h1>My website</h1>
          </body>
        </html>
      HTML
      IO.write('public_html/customize_test.html', html_base)
      @metatag = '<meta property="test" content="TEST">'
    end

    after(:each) do
      FileUtils.rm 'public_html/customize_test.html'
    end

    it 'should return an error if no file is given' do
      expect { @rake.invoke_task('site:customize_output') }.to \
        output("No source file given\n").to_stderr
    end

    it 'should customize a given html file with simple template' do
      Neruda::Config.load_test(
        'templates' => [
          { 'selector' => 'title',
            'content' => @metatag }
        ]
      )
      @rake.invoke_task('site:customize_output[public_html/customize_test.html]')
      result = <<~RESULT
        <!DOCTYPE html>
        <html>
          <head>
        <!-- Neruda Template: #{Digest::MD5.hexdigest(@metatag)} -->

            <title>My website</title>
        <meta property="test" content="TEST">
          </head>
          <body>
            <h1>My website</h1>
          </body>
        </html>
      RESULT
      expect(IO.read('public_html/customize_test.html')).to eq(result)
    end

    it 'should customize a given html file with before' do
      Neruda::Config.load_test(
        'templates' => [
          { 'selector' => 'title',
            'type' => 'before',
            'content' => @metatag }
        ]
      )
      @rake.invoke_task('site:customize_output[public_html/customize_test.html]')
      result = <<~RESULT
        <!DOCTYPE html>
        <html>
          <head>
        <!-- Neruda Template: #{Digest::MD5.hexdigest(@metatag)} -->

            <meta property="test" content="TEST">
        <title>My website</title>
          </head>
          <body>
            <h1>My website</h1>
          </body>
        </html>
      RESULT
      expect(IO.read('public_html/customize_test.html')).to eq(result)
    end

    it 'should customize a given html file with after' do
      Neruda::Config.load_test(
        'templates' => [
          { 'selector' => 'title',
            'type' => 'after',
            'content' => @metatag }
        ]
      )
      Rake.verbose(true) # Test that in the same time
      @rake.invoke_task('site:customize_output[public_html/customize_test.html]')
      result = <<~RESULT
        <!DOCTYPE html>
        <html>
          <head>
        <!-- Neruda Template: #{Digest::MD5.hexdigest(@metatag)} -->

            <title>My website</title>
        <meta property="test" content="TEST">
          </head>
          <body>
            <h1>My website</h1>
          </body>
        </html>
      RESULT
      expect(IO.read('public_html/customize_test.html')).to eq(result)
    end

    it 'should customize a given html file with replace content' do
      Neruda::Config.load_test(
        'templates' => [
          { 'selector' => 'body>h1',
            'type' => 'replace',
            'content' => '<p>Toto tata</p>' }
        ]
      )
      @rake.invoke_task('site:customize_output[public_html/customize_test.html]')
      result = <<~RESULT
        <!DOCTYPE html>
        <html>
          <head>
        <!-- Neruda Template: #{Digest::MD5.hexdigest('<p>Toto tata</p>')} -->

            <title>My website</title>
          </head>
          <body>
            <p>Toto tata</p>
          </body>
        </html>
      RESULT
      expect(IO.read('public_html/customize_test.html')).to eq(result)
    end

    describe 'Multiple pass on customize' do
      before(:each) do
        FileUtils.mkdir_p 'public_html/customize'
        @html_base = <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <title>My website</title>
            </head>
            <body>
              <h1>My website</h1>
            </body>
          </html>
        HTML
        @metatag = '<meta property="test" content="TEST">'
        @result = <<~RESULT
          <!DOCTYPE html>
          <html>
            <head>
          <!-- Neruda Template: #{Digest::MD5.hexdigest(@metatag)} -->

              <meta property="test" content="TEST">
          <title>My website</title>
            </head>
            <body>
              <h1>My website</h1>
            </body>
          </html>
        RESULT
        IO.write('public_html/customize/test.html', @html_base)
        Neruda::Config.load_test(
          'templates' => [
            { 'selector' => 'title',
              'path' => '/customize/*',
              'type' => 'before',
              'content' => @metatag }
          ]
        )
      end

      after(:each) do
        FileUtils.rm_r 'public_html/customize', force: true
      end

      it 'should customize a file on a specific path' do
        @rake.invoke_task('site:customize_output[public_html/customize_test.html]')
        expect(IO.read('public_html/customize_test.html')).to eq(@html_base)
        @rake.options.build_all = true
        @rake['site:customize_output'].reenable
        @rake.invoke_task('site:customize_output[public_html/customize/test.html]')
        expect(IO.read('public_html/customize/test.html')).to eq(@result)
      end

      it 'should not customize twice a file' do
        @rake.invoke_task('site:customize_output[public_html/customize/test.html]')
        expect(IO.read('public_html/customize/test.html')).to eq(@result)
        @rake.options.build_all = true
        @rake['site:customize_output'].reenable
        @rake.invoke_task('site:customize_output[public_html/customize/test.html]')
        expect(IO.read('public_html/customize/test.html')).to eq(@result)
      end
    end
  end
end

describe 'Generate indexes process' do
  before(:all) do
    init_testing_website
    @rake = init_rake_and_install_org
    org_content = <<~ORG
      #+title: Index file

      My website
    ORG
    IO.write('src/index.org', org_content)
    FileUtils.mkdir_p 'src/news'
    file1 = <<~ORG
      #+title: Index file
      #+keywords: toto, tata

      My website
    ORG
    IO.write('src/news/test1.org', file1)
    file2 = <<~ORG
      #+title: Index file
      #+keywords: toto

      My website
    ORG
    IO.write('src/news/test2.org', file2)
  end

  before(:each) do
    @rake.options.build_all = true
    @rake.tasks.each(&:reenable)
  end

  after(:each) do
    FileUtils.rm_r ['tmp', 'src/tags', 'public_html'], force: true
  end

  after(:all) do
    Dir.chdir File.expand_path('../', __dir__)
    FileUtils.rm_r 'spec/data/website_testing', force: true
  end

  it 'should not generate index without blog folder' do
    expect(File.exist?('src/news/test1.org')).to be(true)
    @rake.invoke_task('site:index')
    expect(File.exist?('public_html/tags/toto.html')).to be(false)
    expect(File.exist?('public_html/tags/tata.html')).to be(false)
    expect(File.exist?('public_html/feeds/index.xml')).to be(false)
    expect(File.exist?('public_html/feeds/toto.xml')).to be(false)
    expect(File.exist?('public_html/feeds/tata.xml')).to be(false)
  end

  it 'should not generate index without blog folder when calling build' do
    expect(File.exist?('src/news/test1.org')).to be(true)
    @rake.invoke_task('site:build')
    expect(File.exist?('public_html/tags/toto.html')).to be(false)
    expect(File.exist?('public_html/tags/tata.html')).to be(false)
    expect(File.exist?('public_html/feeds/index.xml')).to be(false)
    expect(File.exist?('public_html/feeds/toto.xml')).to be(false)
    expect(File.exist?('public_html/feeds/tata.xml')).to be(false)
  end

  it 'should generate indexes with a correct blog path' do
    expect(File.exist?('src/news/test1.org')).to be(true)
    Neruda::Config.load_test('blog_path' => 'news')
    @rake.invoke_task('site:index')
    expect(File.exist?('public_html/tags/toto.html')).to be(true)
    expect(File.exist?('public_html/tags/tata.html')).to be(true)
    expect(File.exist?('public_html/feeds/index.xml')).to be(true)
    expect(File.exist?('public_html/feeds/toto.xml')).to be(true)
    expect(File.exist?('public_html/feeds/tata.xml')).to be(true)
  end

  it 'should generate indexes with a correct blog path, even with build' do
    expect(File.exist?('src/news/test1.org')).to be(true)
    Neruda::Config.load_test('blog_path' => 'news')
    @rake.invoke_task('site:build')
    expect(File.exist?('public_html/tags/toto.html')).to be(true)
    expect(File.exist?('public_html/tags/tata.html')).to be(true)
    expect(File.exist?('public_html/feeds/index.xml')).to be(true)
    expect(File.exist?('public_html/feeds/toto.xml')).to be(true)
    expect(File.exist?('public_html/feeds/tata.xml')).to be(true)
  end
end
