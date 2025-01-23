mod interfaces {
    pub mod IReceiver;
    pub mod IExecutor;
}

mod contracts {
    pub mod receiver;
    pub mod executor;
    // pub mod temp;
}

pub mod components {
    pub mod common;
}

mod utils {
    pub mod errors;
}

#[cfg(test)]
pub mod tests {
    pub mod test_integration;
}

pub mod mocks {
    pub mod erc20;
    pub mod test_dapp;
}