// ── SnakeApp ──────────────────────────────────────────────────────────────────

pub struct SnakeApp {
    inner: UnsafeCell<Game>,
}

// SAFETY: Callers must serialize access to this interior-mutable state. SMP
// safety has not been independently validated.
unsafe impl Sync for SnakeApp {}

impl SnakeApp {
    pub fn new() -> Self {
        SnakeApp {
            inner: UnsafeCell::new(Game::new()),
        }
    }

    fn g(&self) -> &mut Game {
        // SAFETY: the desktop must ensure serialized access and must not retain
        // another mutable reference to this state.
        unsafe { &mut *self.inner.get() }
    }
}
