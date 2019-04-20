# frozen_string_literal: true

require 'climate_control'
require 'video2gif'


describe Video2gif::Utils do
  describe '::is_executable?' do
    subject { Video2gif::Utils.is_executable?(executable) }

    before { allow(File).to receive(:executable?).and_return(false) }

    context 'on unix' do
      let(:executable) { 'ffmpeg' }
      let(:path_to_executable) { '/usr/local/bin' }
      let(:path_separator) { ':' }
      let(:path) { %w(/usr/local/bin /usr/bin /bin /usr/sbin /sbin).join(path_separator) }

      before { stub_const('File::PATH_SEPARATOR', path_separator) }

      around do |example|
        ClimateControl.modify PATH: path do
          example.run
        end
      end

      context 'when ffmpeg is on path' do
        before do
          allow(File)
            .to receive(:executable?)
            .with(File.join(path_to_executable, executable))
            .and_return(true)
        end

        it { is_expected.to be true }
      end

      context 'when ffmpeg is not on path' do
        it { is_expected.to be false }
      end
    end

    context 'on windows' do
      let(:executable) { 'ffmpeg' }
      let(:path_to_executable) { 'C:/Program Files/ffmpeg/bin' }
      let(:path_separator) { ';' }
      let(:path) { %w(C:/Windows C:/Windows/system32 C:/Program\ Files/ffmpeg/bin).join(path_separator) }
      let(:pathext) { %w(.COM .EXE .BAT .CMD).join(path_separator) }

      before { stub_const('File::PATH_SEPARATOR', path_separator) }

      around do |example|
        ClimateControl.modify PATH: path, PATHEXT: pathext do
          example.run
        end
      end

      context 'when ffmpeg is on path' do
        before do
          allow(File)
            .to receive(:executable?)
            .with(File.join(path_to_executable, "#{executable}.EXE"))
            .and_return(true)
        end

        it { is_expected.to be true }
      end

      context 'when ffmpeg is not on path' do
        it { is_expected.to be false }
      end
    end
  end
end
