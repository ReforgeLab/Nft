module nft::utils {
    use std::{string::{Self, String}, type_name::get_with_original_ids};

    public(package) fun type_to_string<T>(): String {
        string::from_ascii(get_with_original_ids<T>().into_string())
    }
}
