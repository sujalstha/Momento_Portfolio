// SupabaseManager.swift
// Single shared Supabase client. Reads public config from AuthSecrets — never
// the secret/service-role key (that stays in the Supabase dashboard).

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: AuthSecrets.supabaseURL,
    supabaseKey: AuthSecrets.supabaseAnonKey
)
