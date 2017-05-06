describe IOEventLoop::Future do
  let(:loop) { IOEventLoop.new }

  describe "#result" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently{ :result } }

    context "when everything goes fine" do
      it { is_expected.to be :result }
    end

    context "when resuming a fiber raises an error" do
      # e.g. resuming the fiber raises a FiberError
      before { allow(Fiber.current).to receive(:transfer).and_raise FiberError, 'transfer error' }
      it { is_expected.to raise_error FiberError, 'transfer error' }
    end
  end

  describe "#result with a timeout" do
    subject { concurrency.result within: 0.0001, timeout_result: timeout_result }

    let(:timeout_result) { :timeout_result }

    context "when the result arrives in time" do
      let(:concurrency) { loop.concurrently{ :result } }
      it { is_expected.to be :result }
    end

    context "when evaluation of result is too slow" do
      let(:concurrency) { loop.concurrently do
        loop.now_in(0.0002).await
        :result
      end }

      context "when the timeout result is a timeout error" do
        let(:timeout_result) { IOEventLoop::TimeoutError.new("Time's up!") }
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
      end

      context "when the timeout result is not an timeout error" do
        let(:timeout_result) { :timeout_result }
        it { is_expected.to be :timeout_result }
      end
    end
  end

  describe "#cancel" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently{ loop.now_in(0.0002).await } }

    context "when doing it before requesting the result" do
      before { concurrency.cancel *reason }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end

    context "when doing it after requesting the result" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        concurrency.cancel *reason
      end }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end
  end
end